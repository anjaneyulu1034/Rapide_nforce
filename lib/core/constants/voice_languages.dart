/// Spoken-language options for the voice-to-text Notes field — mirrors
/// web's `VOICE_SOURCE_LANGUAGES`/`VOICE_SOURCE_LANGUAGE_LABELS`
/// (`src/constants/voiceTranslation.ts`). The backend transcribes audio in
/// [code] and translates it to English before returning `translatedText`.
class VoiceLanguageOption {
  const VoiceLanguageOption(this.code, this.label);

  final String code;
  final String label;
}

const List<VoiceLanguageOption> kVoiceSourceLanguages = [
  VoiceLanguageOption('pa-IN', 'Punjabi'),
  VoiceLanguageOption('ru-RU', 'Russian'),
  VoiceLanguageOption('ta-IN', 'Tamil'),
  VoiceLanguageOption('en-US', 'English'),
];

const String kVoiceDefaultSourceLanguage = 'pa-IN';
