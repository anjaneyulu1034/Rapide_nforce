import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:rapide_nforce/core/constants/app_colors.dart';
import 'package:rapide_nforce/core/constants/voice_languages.dart';
import 'package:rapide_nforce/core/utils/app_toast.dart';
import 'package:rapide_nforce/services/voice_translation_service.dart';
import 'package:record/record.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

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
  final stt.SpeechToText _speech = stt.SpeechToText();
  String _language = kVoiceDefaultSourceLanguage;
  bool _recording = false;
  bool _uploading = false;
  bool _speechReady = false;
  String _liveTranscript = '';
  Duration _elapsed = Duration.zero;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _recorder.dispose();
    if (_speech.isListening) _speech.stop();
    super.dispose();
  }

  /// Picks the on-device recognizer locale matching [_language]'s language
  /// prefix (e.g. `pa-IN` → any installed `pa_*` locale). Engines vary by
  /// device/OS, so this degrades to the device default rather than failing.
  Future<String?> _resolveLocaleId(List<stt.LocaleName> locales) async {
    final prefix = _language.split('-').first.toLowerCase();
    for (final locale in locales) {
      if (locale.localeId.toLowerCase().startsWith(prefix)) {
        return locale.localeId;
      }
    }
    return null;
  }

  /// Runs on-device speech recognition alongside the audio recording so a
  /// transcript can be sent as `browserTranscript` — the same field web's
  /// desktop build fills from `webkitSpeechRecognition`. The backend already
  /// falls back to translating that text when server-side Azure Speech isn't
  /// configured, so this is what makes voice notes work without any backend
  /// changes. Best-effort: any failure here just leaves browserTranscript
  /// empty and voice notes behaves as before.
  Future<void> _startLiveTranscription() async {
    _liveTranscript = '';
    try {
      _speechReady = await _speech.initialize(
        onError: (_) {},
        onStatus: (_) {},
      );
      if (!_speechReady) return;
      final locales = await _speech.locales();
      final localeId = await _resolveLocaleId(locales);
      await _speech.listen(
        onResult: (result) => _liveTranscript = result.recognizedWords,
        listenOptions: stt.SpeechListenOptions(
          localeId: localeId,
          listenMode: stt.ListenMode.dictation,
          partialResults: true,
          cancelOnError: false,
          listenFor: const Duration(minutes: 5),
          pauseFor: const Duration(minutes: 5),
        ),
      );
    } catch (_) {
      _speechReady = false;
    }
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
    unawaited(_startLiveTranscription());
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
    if (_speech.isListening) await _speech.stop();
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
      browserTranscript: _liveTranscript,
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
