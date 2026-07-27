import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_error.dart';

enum VoiceDictationStatus { idle, initializing, listening, done, error }

/// Wraps `speech_to_text` behind a single [ChangeNotifier] so any screen can
/// start/stop a dictation session and read the live transcript.
class VoiceDictationService extends ChangeNotifier {
  VoiceDictationService._();

  static final VoiceDictationService instance = VoiceDictationService._();

  final stt.SpeechToText _speech = stt.SpeechToText();

  VoiceDictationStatus _status = VoiceDictationStatus.idle;
  String _transcript = '';
  String? _errorMessage;
  bool _speechAvailable = false;

  VoiceDictationStatus get status => _status;
  String get transcript => _transcript;
  String? get errorMessage => _errorMessage;
  bool get isListening => _status == VoiceDictationStatus.listening;

  Future<bool> _ensureInitialized() async {
    if (_speechAvailable) return true;
    _speechAvailable = await _speech.initialize(
      onError: (SpeechRecognitionError error) {
        _errorMessage = error.errorMsg;
        _status = VoiceDictationStatus.error;
        notifyListeners();
      },
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          if (_status == VoiceDictationStatus.listening) {
            _status = VoiceDictationStatus.done;
            notifyListeners();
          }
        }
      },
    );
    return _speechAvailable;
  }

  Future<void> startListening() async {
    _transcript = '';
    _errorMessage = null;
    _status = VoiceDictationStatus.initializing;
    notifyListeners();

    final available = await _ensureInitialized();
    if (!available) {
      _status = VoiceDictationStatus.error;
      _errorMessage =
          'Speech recognition is not available on this device. Check microphone and speech permissions.';
      notifyListeners();
      return;
    }

    _status = VoiceDictationStatus.listening;
    notifyListeners();

    await _speech.listen(
      onResult: (result) {
        _transcript = result.recognizedWords;
        notifyListeners();
      },
      listenOptions: stt.SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
        listenMode: stt.ListenMode.dictation,
        listenFor: const Duration(minutes: 2),
        pauseFor: const Duration(seconds: 5),
      ),
    );
  }

  Future<void> stopListening() async {
    if (_status != VoiceDictationStatus.listening) return;
    await _speech.stop();
    _status = VoiceDictationStatus.done;
    notifyListeners();
  }

  Future<void> cancel() async {
    await _speech.cancel();
    _status = VoiceDictationStatus.idle;
    _transcript = '';
    _errorMessage = null;
    notifyListeners();
  }

  void reset() {
    _status = VoiceDictationStatus.idle;
    _transcript = '';
    _errorMessage = null;
    notifyListeners();
  }
}
