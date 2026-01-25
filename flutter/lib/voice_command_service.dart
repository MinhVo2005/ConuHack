// voice_command_service.dart
// Handles shake detection, audio recording, and voice command processing

import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'dart:convert';
import 'backend_service.dart';
import 'login_screen.dart'; // For UserSession

/// Exception types for voice command errors
class VoiceCommandException implements Exception {
  final String message;
  final VoiceCommandErrorType type;

  VoiceCommandException(this.message, this.type);

  @override
  String toString() => message;
}

enum VoiceCommandErrorType {
  microphonePermissionDenied,
  microphonePermissionPermanentlyDenied,
  recordingFailed,
  networkUnavailable,
  serverError,
  transcriptionFailed,
}

/// States for the voice command flow
enum VoiceCommandState {
  idle,
  listening, // Recording audio
  processing, // Sending to server / waiting for response
  responding, // Playing back TTS response
  error,
}

/// Callback type for state changes
typedef VoiceStateCallback = void Function(VoiceCommandState state, {String? message, String? error});

class VoiceCommandService {
  static final VoiceCommandService _instance = VoiceCommandService._internal();
  factory VoiceCommandService() => _instance;
  VoiceCommandService._internal();

  // Shake detection
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  DateTime? _lastShakeTime;
  static const double _shakeThreshold = 15.0; // m/s² - adjust sensitivity
  static const Duration _shakeDebounce = Duration(milliseconds: 500);

  // Recording
  final AudioRecorder _recorder = AudioRecorder();
  Timer? _recordingTimer;
  static const Duration _maxRecordingDuration = Duration(seconds: 10);
  String? _currentRecordingPath;

  // TTS Playback
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isSpeaking = false;

  // State
  VoiceCommandState _state = VoiceCommandState.idle;
  VoiceCommandState get state => _state;

  // Callbacks
  VoiceStateCallback? onStateChanged;
  void Function(String transcript)? onTranscriptReceived;
  void Function(String response)? onResponseReceived;
  /// Called when a command completes successfully (e.g., to refresh account data)
  void Function(String action, Map<String, dynamic>? data)? onCommandSuccess;

  /// Initialize the service and start listening for shakes
  Future<void> initialize() async {
    await _startShakeDetection();
  }

  /// Clean up resources
  void dispose() {
    _accelerometerSubscription?.cancel();
    _recordingTimer?.cancel();
    _recorder.dispose();
    _audioPlayer.dispose();
  }

  /// Start listening for accelerometer events
  Future<void> _startShakeDetection() async {
    _accelerometerSubscription?.cancel();

    _accelerometerSubscription = accelerometerEventStream(
      samplingPeriod: const Duration(milliseconds: 100),
    ).listen(_onAccelerometerEvent);
  }

  void _onAccelerometerEvent(AccelerometerEvent event) {
    // Calculate magnitude of acceleration
    final double magnitude = sqrt(
      event.x * event.x + event.y * event.y + event.z * event.z
    );

    // Subtract gravity (~9.8 m/s²) and check if it exceeds threshold
    final double shakeIntensity = (magnitude - 9.8).abs();

    if (shakeIntensity > _shakeThreshold) {
      _onShakeDetected();
    }
  }

  void _onShakeDetected() {
    final now = DateTime.now();

    // Debounce rapid shakes
    if (_lastShakeTime != null &&
        now.difference(_lastShakeTime!) < _shakeDebounce) {
      return;
    }
    _lastShakeTime = now;

    // Handle shake based on current state
    if (_state == VoiceCommandState.idle) {
      _startRecording();
    } else if (_state == VoiceCommandState.listening) {
      _stopRecordingAndProcess();
    }
  }

  /// Check and request microphone permission
  Future<bool> _checkMicrophonePermission() async {
    var status = await Permission.microphone.status;

    if (status.isDenied) {
      status = await Permission.microphone.request();
    }

    if (status.isPermanentlyDenied) {
      _setState(VoiceCommandState.error);
      throw VoiceCommandException(
        'Microphone permission permanently denied. Please enable it in settings.',
        VoiceCommandErrorType.microphonePermissionPermanentlyDenied,
      );
    }

    if (!status.isGranted) {
      _setState(VoiceCommandState.error);
      throw VoiceCommandException(
        'Microphone permission denied.',
        VoiceCommandErrorType.microphonePermissionDenied,
      );
    }

    return true;
  }

  /// Start recording audio
  Future<void> _startRecording() async {
    try {
      // Check permission first
      await _checkMicrophonePermission();

      // Check if we can record
      if (!await _recorder.hasPermission()) {
        throw VoiceCommandException(
          'Microphone permission not available.',
          VoiceCommandErrorType.microphonePermissionDenied,
        );
      }

      // Get temp directory for recording
      final directory = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _currentRecordingPath = '${directory.path}/voice_command_$timestamp.m4a';

      // Start recording
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: _currentRecordingPath!,
      );

      _setState(VoiceCommandState.listening, message: 'Listening...');

      // Start timeout timer
      _recordingTimer?.cancel();
      _recordingTimer = Timer(_maxRecordingDuration, () {
        _stopRecordingAndProcess();
      });
    } catch (e) {
      if (e is VoiceCommandException) {
        _setState(VoiceCommandState.error, error: e.message);
        rethrow;
      }
      _setState(VoiceCommandState.error, error: 'Failed to start recording: $e');
      throw VoiceCommandException(
        'Failed to start recording: $e',
        VoiceCommandErrorType.recordingFailed,
      );
    }
  }

  /// Stop recording and send to server for processing
  Future<void> _stopRecordingAndProcess() async {
    _recordingTimer?.cancel();

    if (_state != VoiceCommandState.listening) {
      return;
    }

    try {
      // Stop recording
      final path = await _recorder.stop();

      if (path == null || path.isEmpty) {
        throw VoiceCommandException(
          'No audio recorded.',
          VoiceCommandErrorType.recordingFailed,
        );
      }

      _setState(VoiceCommandState.processing, message: 'Processing...');

      // Upload to server
      await _uploadAndProcess(path);
    } catch (e) {
      if (e is VoiceCommandException) {
        _setState(VoiceCommandState.error, error: e.message);
      } else {
        _setState(VoiceCommandState.error, error: 'Processing failed: $e');
      }
      // Return to idle after showing error briefly
      Future.delayed(const Duration(seconds: 2), () {
        if (_state == VoiceCommandState.error) {
          _setState(VoiceCommandState.idle);
        }
      });
    }
  }

  /// Upload audio file to server for transcription and command processing
  Future<void> _uploadAndProcess(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw VoiceCommandException(
          'Recording file not found.',
          VoiceCommandErrorType.recordingFailed,
        );
      }

      // Check if user is logged in
      final userId = UserSession.instance.userId;
      if (userId == null) {
        throw VoiceCommandException(
          'Please log in first.',
          VoiceCommandErrorType.serverError,
        );
      }

      // Step 1: Transcribe audio
      _setState(VoiceCommandState.processing, message: 'Transcribing...');

      final transcribeUri = Uri.parse('${BackendService.apiUrl}/transcribe');
      final transcribeRequest = http.MultipartRequest('POST', transcribeUri);

      transcribeRequest.files.add(await http.MultipartFile.fromPath(
        'file',
        filePath,
        filename: 'voice_command.m4a',
      ));

      final transcribeStreamedResponse = await transcribeRequest.send().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw VoiceCommandException(
            'Request timed out. Please check your connection.',
            VoiceCommandErrorType.networkUnavailable,
          );
        },
      );

      final transcribeResponse = await http.Response.fromStream(transcribeStreamedResponse);

      // Clean up temp file
      try {
        await file.delete();
      } catch (_) {}

      if (transcribeResponse.statusCode != 200) {
        throw VoiceCommandException(
          'Transcription failed: ${transcribeResponse.statusCode}',
          VoiceCommandErrorType.serverError,
        );
      }

      final transcribeData = jsonDecode(transcribeResponse.body);
      final transcript = transcribeData['transcript'] as String? ?? '';

      if (transcript.isEmpty) {
        throw VoiceCommandException(
          'No speech detected. Please try again.',
          VoiceCommandErrorType.transcriptionFailed,
        );
      }

      // Notify listener of transcript
      onTranscriptReceived?.call(transcript);
      debugPrint('Transcript: $transcript');

      // Step 2: Process command with Gemini
      _setState(VoiceCommandState.processing, message: 'Understanding...');

      final commandUri = Uri.parse('${BackendService.apiUrl}/voice-command');
      final commandResponse = await http.post(
        commandUri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'transcript': transcript,
        }),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw VoiceCommandException(
            'Command processing timed out.',
            VoiceCommandErrorType.networkUnavailable,
          );
        },
      );

      if (commandResponse.statusCode != 200) {
        throw VoiceCommandException(
          'Command processing failed: ${commandResponse.statusCode}',
          VoiceCommandErrorType.serverError,
        );
      }

      final commandData = jsonDecode(commandResponse.body);
      final spokenResponse = commandData['spoken_response'] as String? ?? 'Something went wrong.';
      final success = commandData['success'] as bool? ?? false;
      final action = commandData['action'] as String? ?? 'unknown';
      final data = commandData['data'] as Map<String, dynamic>?;

      debugPrint('Action: $action, Success: $success');
      debugPrint('Response: $spokenResponse');

      // Notify listener of response
      onResponseReceived?.call(spokenResponse);

      // Notify on successful command (so app can refresh data)
      if (success) {
        onCommandSuccess?.call(action, data);
      }

      // Show the response and play TTS
      _setState(VoiceCommandState.responding, message: spokenResponse);

      // Play TTS audio (non-blocking, runs in parallel with display)
      _playTTSResponse(spokenResponse).then((_) {
        // Return to idle after TTS completes (if still in responding state)
        if (_state == VoiceCommandState.responding) {
          _setState(VoiceCommandState.idle);
        }
      });

      // Fallback: also set a maximum display time in case TTS fails
      final wordCount = spokenResponse.split(' ').length;
      final maxDisplayDuration = Duration(seconds: (wordCount / 2).clamp(5, 15).round());

      Future.delayed(maxDisplayDuration, () {
        if (_state == VoiceCommandState.responding) {
          _setState(VoiceCommandState.idle);
        }
      });
    } on SocketException {
      throw VoiceCommandException(
        'Network unavailable. Please check your connection.',
        VoiceCommandErrorType.networkUnavailable,
      );
    } catch (e) {
      if (e is VoiceCommandException) {
        rethrow;
      }
      throw VoiceCommandException(
        'Failed to process: $e',
        VoiceCommandErrorType.serverError,
      );
    }
  }

  /// Cancel current operation and return to idle
  void cancel() {
    _recordingTimer?.cancel();
    _recorder.stop();
    _setState(VoiceCommandState.idle);
  }

  void _setState(VoiceCommandState newState, {String? message, String? error}) {
    _state = newState;
    onStateChanged?.call(newState, message: message, error: error);
  }

  /// Manually trigger recording (for testing without shake)
  Future<void> toggleRecording() async {
    if (_state == VoiceCommandState.idle) {
      await _startRecording();
    } else if (_state == VoiceCommandState.listening) {
      await _stopRecordingAndProcess();
    }
  }

  /// Fetch TTS audio from server and play it
  Future<void> _playTTSResponse(String text) async {
    if (text.isEmpty) return;

    try {
      _isSpeaking = true;

      // Request TTS audio from server
      final ttsUri = Uri.parse('${BackendService.apiUrl}/text-to-speech');
      final ttsResponse = await http.post(
        ttsUri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'text': text,
          'voice': 'friendly', // Use friendly voice for responses
        }),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('TTS request timed out');
        },
      );

      if (ttsResponse.statusCode != 200) {
        debugPrint('TTS failed: ${ttsResponse.statusCode}');
        return;
      }

      // Save audio to temp file and play
      final directory = await getTemporaryDirectory();
      final audioFile = File('${directory.path}/tts_response.mp3');
      await audioFile.writeAsBytes(ttsResponse.bodyBytes);

      // Play the audio
      await _audioPlayer.setFilePath(audioFile.path);
      await _audioPlayer.play();

      // Wait for playback to complete
      await _audioPlayer.playerStateStream.firstWhere(
        (state) => state.processingState == ProcessingState.completed,
      );

      // Clean up
      try {
        await audioFile.delete();
      } catch (_) {}
    } catch (e) {
      debugPrint('TTS playback error: $e');
    } finally {
      _isSpeaking = false;
    }
  }

  /// Stop TTS playback if currently speaking
  Future<void> stopSpeaking() async {
    if (_isSpeaking) {
      await _audioPlayer.stop();
      _isSpeaking = false;
    }
  }

  /// Check if TTS is currently playing
  bool get isSpeaking => _isSpeaking;
}
