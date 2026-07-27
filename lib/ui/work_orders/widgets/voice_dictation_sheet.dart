import 'package:flutter/material.dart';
import 'package:rapide_nforce/core/constants/app_colors.dart';
import 'package:rapide_nforce/services/voice_dictation_service.dart';

/// Shows the voice dictation bottom sheet. Returns the final transcript
/// when the user taps Done, or null if they cancel/dismiss without one.
Future<String?> showVoiceDictationSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _VoiceDictationSheet(),
  );
}

class _VoiceDictationSheet extends StatefulWidget {
  const _VoiceDictationSheet();

  @override
  State<_VoiceDictationSheet> createState() => _VoiceDictationSheetState();
}

class _VoiceDictationSheetState extends State<_VoiceDictationSheet>
    with SingleTickerProviderStateMixin {
  final _service = VoiceDictationService.instance;
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _service.addListener(_onServiceChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _service.startListening());
  }

  void _onServiceChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _service.removeListener(_onServiceChanged);
    _pulseController.dispose();
    if (_service.isListening) {
      _service.cancel();
    } else {
      _service.reset();
    }
    super.dispose();
  }

  void _onDone() {
    final text = _service.transcript.trim();
    _service.stopListening();
    Navigator.of(context).pop(text.isEmpty ? null : text);
  }

  void _onCancel() {
    Navigator.of(context).pop(null);
  }

  @override
  Widget build(BuildContext context) {
    final status = _service.status;
    final listening = status == VoiceDictationStatus.listening;
    final initializing = status == VoiceDictationStatus.initializing;
    final hasError = status == VoiceDictationStatus.error;

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              hasError
                  ? 'Voice input unavailable'
                  : listening
                      ? 'Listening…'
                      : initializing
                          ? 'Starting…'
                          : 'Dictation finished',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              hasError
                  ? (_service.errorMessage ?? 'Please try again.')
                  : 'Describe the issue, then tap Done.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final scale = listening
                    ? 1.0 + (_pulseController.value * 0.15)
                    : 1.0;
                return Transform.scale(scale: scale, child: child);
              },
              child: Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: hasError
                      ? AppColors.danger.withValues(alpha: 0.12)
                      : AppColors.chromeBlue.withValues(alpha: 0.12),
                ),
                child: Icon(
                  hasError ? Icons.mic_off_rounded : Icons.mic_rounded,
                  size: 36,
                  color: hasError ? AppColors.danger : AppColors.chromeBlue,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 64),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.inputFill,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                _service.transcript.isEmpty
                    ? (listening ? 'Say something…' : ' ')
                    : _service.transcript,
                style: TextStyle(
                  fontSize: 14,
                  color: _service.transcript.isEmpty
                      ? AppColors.textTertiary
                      : AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _onCancel,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(color: AppColors.textPrimary),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: hasError
                        ? () => _service.startListening()
                        : _onDone,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.chromeBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(hasError ? 'Retry' : 'Done'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
