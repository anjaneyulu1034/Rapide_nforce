import 'package:http/http.dart' as http;
import 'package:rapide_nforce/core/constants/api_constants.dart';
import 'package:rapide_nforce/core/models/api_result.dart';
import 'package:rapide_nforce/core/utils/api_parse.dart';
import 'package:rapide_nforce/services/api_client.dart';

/// Result of one `/maintenance/voice/translate` call — mirrors web's
/// `translateAudio` response (`voiceTranslation.service.ts`).
class VoiceTranslationResult {
  const VoiceTranslationResult({
    required this.translatedText,
    this.originalTranscript,
    this.sourceLanguage,
    this.confidence,
  });

  final String translatedText;
  final String? originalTranscript;
  final String? sourceLanguage;
  final num? confidence;

  factory VoiceTranslationResult.fromJson(Map<String, dynamic> json) {
    return VoiceTranslationResult(
      translatedText: json['translatedText']?.toString() ??
          json['translated_text']?.toString() ??
          '',
      originalTranscript: json['originalTranscript']?.toString() ??
          json['original_transcript']?.toString(),
      sourceLanguage: json['sourceLanguage']?.toString() ??
          json['source_language']?.toString(),
      confidence: json['confidence'] as num?,
    );
  }
}

/// Records → uploads → server-transcribes-and-translates audio for the
/// voice-to-text Notes field — a Dart port of web's `voiceTranslation.service.ts`
/// backed by the same `/maintenance/voice/*` endpoints (already implemented
/// server-side; no backend changes needed).
class VoiceTranslationService {
  VoiceTranslationService._();

  static final VoiceTranslationService instance = VoiceTranslationService._();

  final ApiClient _api = ApiClient.instance;

  /// Uploads the recorded WAV at [audioPath] for transcription + translation
  /// to English. [fieldName] identifies which form field this recording is
  /// for (e.g. `'notes'`) — matches web's `VOICE_SUPPORTED_FIELDS` values.
  Future<ApiResult<VoiceTranslationResult>> translateAudio({
    required String audioPath,
    required String fieldName,
    required String sourceLanguage,
    required String sessionId,
    int? workOrderId,
    String? browserTranscript,
  }) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse('dummy'));
      request.fields['fieldName'] = fieldName;
      request.fields['sourceLanguage'] = sourceLanguage;
      request.fields['sessionId'] = sessionId;
      if (workOrderId != null) {
        request.fields['workOrderId'] = '$workOrderId';
      }
      // Lets the backend's text-translation fallback handle this note when
      // Azure Speech isn't configured server-side — mirrors web's desktop-dev
      // path (`browserTranscript` in `useVoiceTranslation.ts`), produced here
      // by on-device `speech_to_text` instead of the browser's own engine.
      if (browserTranscript != null && browserTranscript.trim().isNotEmpty) {
        request.fields['browserTranscript'] = browserTranscript.trim();
      }
      request.files.add(await http.MultipartFile.fromPath('audio', audioPath));

      final body = await _api.parseJson(
        () => _api.postMultipart(ApiConstants.voiceTranslate, request),
        onSuccess: (b) => b,
      );
      final data = ApiParse.unwrapData(body);
      if (data is Map) {
        return ApiResult.ok(
          VoiceTranslationResult.fromJson(Map<String, dynamic>.from(data)),
        );
      }
      return ApiResult.fail('Invalid response from server.');
    } on ApiClientException catch (e) {
      return ApiResult.fail(e.message, statusCode: e.statusCode);
    } catch (_) {
      return ApiResult.fail('Failed to translate voice note.');
    }
  }

  /// Retroactively links a recording session (started before the work order
  /// existed) to the newly created work order — mirrors web's
  /// `linkSession`, called once after a successful create.
  Future<ApiResult<void>> linkSession({
    required int workOrderId,
    required String sessionId,
  }) async {
    try {
      await _api.parseJson(
        () => _api.post(
          '${ApiConstants.workOrders}/$workOrderId${ApiConstants.voiceLinkSessionSuffix}',
          body: {'sessionId': sessionId},
        ),
        onSuccess: (b) => b,
      );
      return ApiResult.ok(null);
    } on ApiClientException catch (e) {
      return ApiResult.fail(e.message, statusCode: e.statusCode);
    } catch (_) {
      return ApiResult.fail('Failed to link voice session.');
    }
  }
}
