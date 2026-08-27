import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:rapide_nforce/core/constants/app_colors.dart';
import 'package:rapide_nforce/core/constants/voice_languages.dart';
import 'package:rapide_nforce/core/utils/app_toast.dart';
import 'package:rapide_nforce/services/voice_translation_service.dart';
import 'package:record/record.dart';

/// Generates a session id shared by every voice recording made within one
/// form session — mirrors web's `voiceSessionIdRef` (one id per drawer
/// instance, reused across fields, linked to the work order after create).
String generateVoiceSessionId() =>
    'wo_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1 << 31)}';

/// Records a short voice note, uploads it for server-side transcription +
/// translation to English (`VoiceTranslationService`), and appends the
/// result to [onTranscribed] — the mobile port of web's mic + "I speak
/// [Language]" control on `VoiceTranslationField.tsx`. Renders as a compact
/// control row meant to sit directly above the target text field.
class VoiceNotesRecorderRow extends StatefulWidget {
  const VoiceNotesRecorderRow({
    super.key,
    required this.fieldName,
    required this.sessionId,
    required this.onTranscribed,
    this.workOrderId,
  });

  final String fieldName;
  final String sessionId;
  final ValueChanged<String> onTranscribed;
  final int? workOrderId;

  @override
  State<VoiceNotesRecorderRow> createState() => _VoiceNotesRecorderRowState();
}

class _VoiceNotesRecorderRowState extends State<VoiceNotesRecorderRow> {
  final AudioRecorder _recorder = AudioRecorder();
  String _language = kVoiceDefaultSourceLanguage;
  bool _recording = false;
  bool _uploading = false;
  Duration _elapsed = Duration.zero;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      AppToast.showError('Microphone permission is required for voice notes.');
      return;
    }
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/voice_note_${DateTime.now().millisecondsSinceEpoch}.wav';
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.wav, sampleRate: 16000, numChannels: 1),
      path: path,
    );
    if (!mounted) return;
    setState(() {
      _recording = true;
      _elapsed = Duration.zero;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsed += const Duration(seconds: 1));
    });
  }

  Future<void> _stopRecording() async {
    _timer?.cancel();
    final path = await _recorder.stop();
    if (!mounted) return;
    setState(() => _recording = false);
    if (path == null) return;

    setState(() => _uploading = true);
    final result = await VoiceTranslationService.instance.translateAudio(
      audioPath: path,
      fieldName: widget.fieldName,
      sourceLanguage: _language,
      sessionId: widget.sessionId,
      workOrderId: widget.workOrderId,
    );
    if (!mounted) return;
    setState(() => _uploading = false);

    final text = result.data?.translatedText.trim() ?? '';
    if (!result.isSuccess || text.isEmpty) {
      AppToast.showError(
        result.message ?? 'Could not transcribe the recording. Please try again.',
      );
      return;
    }
    widget.onTranscribed(text);
    AppToast.showSuccess('Voice note added — you can edit the text before saving.');
  }

  String _formatElapsed(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(Icons.mic_none_rounded, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Text(
            'I speak',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(width: 6),
          DropdownButton<String>(
            value: _language,
            isDense: true,
            underline: const SizedBox.shrink(),
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
            items: kVoiceSourceLanguages
                .map(
                  (l) => DropdownMenuItem(value: l.code, child: Text(l.label)),
                )
                .toList(),
            onChanged: (_recording || _uploading)
                ? null
                : (v) => setState(() => _language = v ?? _language),
          ),
          const Spacer(),
          if (_recording) ...[
            Icon(Icons.fiber_manual_record, size: 12, color: AppColors.danger),
            const SizedBox(width: 4),
            Text(
              _formatElapsed(_elapsed),
              style: TextStyle(
                fontSize: 12,
                color: AppColors.danger,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 8),
          ],
          _uploading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: _recording ? _stopRecording : _startRecording,
                  child: Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _recording
                          ? AppColors.danger.withValues(alpha: 0.15)
                          : AppColors.primary.withValues(alpha: 0.12),
                    ),
                    child: Icon(
                      _recording ? Icons.stop_rounded : Icons.mic_rounded,
                      size: 18,
                      color: _recording ? AppColors.danger : AppColors.primary,
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}
