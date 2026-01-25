// voice_overlay.dart
// Global visual overlay for voice command states

import 'package:flutter/material.dart';
import 'voice_command_service.dart';

/// Global overlay widget that shows voice command status
/// Wraps the entire app to work on any screen
class VoiceCommandOverlay extends StatefulWidget {
  final Widget child;
  /// Optional callback when a voice command succeeds (for refreshing data)
  final void Function(String action, Map<String, dynamic>? data)? onCommandSuccess;

  const VoiceCommandOverlay({
    super.key,
    required this.child,
    this.onCommandSuccess,
  });

  /// Access the voice service to register callbacks from anywhere in the app
  static VoiceCommandService get voiceService => VoiceCommandService();

  @override
  State<VoiceCommandOverlay> createState() => _VoiceCommandOverlayState();
}

class _VoiceCommandOverlayState extends State<VoiceCommandOverlay>
    with TickerProviderStateMixin {
  final VoiceCommandService _voiceService = VoiceCommandService();

  VoiceCommandState _state = VoiceCommandState.idle;
  String? _message;
  String? _error;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _speakerPulseController;
  late Animation<double> _speakerPulseAnimation;

  @override
  void initState() {
    super.initState();

    // Setup pulse animation for listening state
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Setup speaker pulse animation for responding state
    _speakerPulseController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _speakerPulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _speakerPulseController, curve: Curves.easeInOut),
    );

    // Initialize voice service
    _voiceService.onStateChanged = _onStateChanged;
    _voiceService.onTranscriptReceived = _onTranscriptReceived;
    _voiceService.onCommandSuccess = _onCommandSuccess;
    _voiceService.initialize();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _speakerPulseController.dispose();
    _voiceService.dispose();
    super.dispose();
  }

  void _onStateChanged(VoiceCommandState state, {String? message, String? error}) {
    setState(() {
      _state = state;
      _message = message;
      _error = error;
    });

    // Control pulse animation
    if (state == VoiceCommandState.listening) {
      _pulseController.repeat(reverse: true);
      _speakerPulseController.stop();
    } else if (state == VoiceCommandState.responding) {
      _pulseController.stop();
      _pulseController.reset();
      _speakerPulseController.repeat(reverse: true);
    } else {
      _pulseController.stop();
      _pulseController.reset();
      _speakerPulseController.stop();
      _speakerPulseController.reset();
    }
  }

  void _onTranscriptReceived(String transcript) {
    // Could show a snackbar or update UI with transcript
    debugPrint('Transcript received: $transcript');
  }

  void _onCommandSuccess(String action, Map<String, dynamic>? data) {
    // Forward to the parent callback if provided
    widget.onCommandSuccess?.call(action, data);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_state != VoiceCommandState.idle) _buildOverlay(),
      ],
    );
  }

  Widget _buildOverlay() {
    return Positioned.fill(
      child: Material(
        color: Colors.black.withValues(alpha: 0.7),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildStateIcon(),
              const SizedBox(height: 24),
              _buildStateText(),
              if (_state == VoiceCommandState.listening) ...[
                const SizedBox(height: 32),
                _buildCancelButton(),
              ],
              if (_state == VoiceCommandState.responding) ...[
                const SizedBox(height: 32),
                _buildDismissButton(),
              ],
              if (_state == VoiceCommandState.error) ...[
                const SizedBox(height: 32),
                _buildRetryButton(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStateIcon() {
    switch (_state) {
      case VoiceCommandState.listening:
        return AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _pulseAnimation.value,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.red.withValues(alpha: 0.3),
                  border: Border.all(color: Colors.red, width: 4),
                ),
                child: const Icon(
                  Icons.mic,
                  size: 60,
                  color: Colors.white,
                ),
              ),
            );
          },
        );

      case VoiceCommandState.processing:
        return Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.blue.withValues(alpha: 0.3),
            border: Border.all(color: Colors.blue, width: 4),
          ),
          child: const Padding(
            padding: EdgeInsets.all(30),
            child: CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 4,
            ),
          ),
        );

      case VoiceCommandState.responding:
        return AnimatedBuilder(
          animation: _speakerPulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _speakerPulseAnimation.value,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.green.withValues(alpha: 0.3),
                  border: Border.all(color: Colors.green, width: 4),
                ),
                child: const Icon(
                  Icons.volume_up,
                  size: 60,
                  color: Colors.white,
                ),
              ),
            );
          },
        );

      case VoiceCommandState.error:
        return Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.orange.withValues(alpha: 0.3),
            border: Border.all(color: Colors.orange, width: 4),
          ),
          child: const Icon(
            Icons.error_outline,
            size: 60,
            color: Colors.white,
          ),
        );

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildStateText() {
    String text;
    Color color;

    switch (_state) {
      case VoiceCommandState.listening:
        text = _message ?? 'Listening...';
        color = Colors.white;
        break;
      case VoiceCommandState.processing:
        text = _message ?? 'Processing...';
        color = Colors.white;
        break;
      case VoiceCommandState.responding:
        text = _message ?? 'Response';
        color = Colors.white;
        break;
      case VoiceCommandState.error:
        text = _error ?? 'An error occurred';
        color = Colors.orange;
        break;
      default:
        text = '';
        color = Colors.white;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: color,
          fontSize: 18,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildCancelButton() {
    return Column(
      children: [
        Text(
          'Shake again to stop',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: () => _voiceService.cancel(),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: const BorderSide(color: Colors.white),
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
          ),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  Widget _buildRetryButton() {
    return ElevatedButton(
      onPressed: () => _voiceService.toggleRecording(),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
      ),
      child: const Text('Try Again'),
    );
  }

  Widget _buildDismissButton() {
    return Column(
      children: [
        Text(
          'Tap to dismiss',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: () {
            _voiceService.stopSpeaking();
            _voiceService.cancel();
          },
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: const BorderSide(color: Colors.white),
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
          ),
          child: const Text('Done'),
        ),
      ],
    );
  }
}
