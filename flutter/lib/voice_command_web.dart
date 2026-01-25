// voice_command_web.dart
// Platform-specific file operations for web

import 'dart:typed_data';
import 'package:http/http.dart' as http;

/// Get the path for a temporary recording file (returns empty on web, recording uses blob URL)
Future<String> getRecordingPath() async {
  // On web, the record package handles this internally and returns a blob URL
  return '';
}

/// Read audio bytes from a blob URL (web) or file path
Future<Uint8List> readAudioBytes(String path) async {
  // On web, the path is a blob URL - we need to fetch it
  if (path.startsWith('blob:')) {
    final response = await http.get(Uri.parse(path));
    if (response.statusCode == 200) {
      return response.bodyBytes;
    }
    throw Exception('Failed to read audio blob: ${response.statusCode}');
  }
  throw Exception('Invalid audio path for web: $path');
}

/// Delete a temporary file (no-op on web, browser handles blob cleanup)
Future<void> deleteFile(String path) async {
  // On web, blob URLs are automatically cleaned up
  // We could revoke the blob URL here if needed
}

/// Write bytes to a temporary location and return a reference
/// On web, we don't actually write to file - just return a placeholder
Future<String> writeTempAudioFile(Uint8List bytes, String filename) async {
  // On web, we handle audio differently
  // For TTS playback, we'll use a data URL or other approach
  return 'web_audio_$filename';
}
