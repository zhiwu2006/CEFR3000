import 'package:flutter_tts/flutter_tts.dart';
import 'tts_service.dart';

/// Flutter TTS实现的发音服务
class FlutterTtsService implements TtsService {
  late FlutterTts _flutterTts;
  bool _isInitialized = false;
  bool _isPlaying = false;

  @override
  Future<void> init({String locale = 'en-US'}) async {
    if (_isInitialized) return;

    _flutterTts = FlutterTts();
    
    // 设置默认参数
    await _flutterTts.setLanguage(locale);
    await _flutterTts.setSpeechRate(0.44);
    await _flutterTts.setPitch(1.0);
    
    // 设置回调
    _flutterTts.setStartHandler(() {
      _isPlaying = true;
    });
    
    _flutterTts.setCompletionHandler(() {
      _isPlaying = false;
    });
    
    _flutterTts.setErrorHandler((msg) {
      _isPlaying = false;
      print('TTS Error: $msg');
    });

    _isInitialized = true;
  }

  @override
  Future<void> speak(String text) async {
    if (!_isInitialized) {
      await init();
    }
    
    try {
      await _flutterTts.speak(text);
    } catch (e) {
      print('TTS speak error: $e');
      // 发音失败不阻塞应用
    }
  }

  @override
  Future<void> stop() async {
    if (!_isInitialized) return;
    
    try {
      await _flutterTts.stop();
      _isPlaying = false;
    } catch (e) {
      print('TTS stop error: $e');
    }
  }

  @override
  Future<void> setSpeechRate(double rate) async {
    if (!_isInitialized) return;
    
    try {
      // rate通常在0.0-1.0之间，但不同平台可能有不同范围
      final clampedRate = rate.clamp(0.1, 1.0);
      await _flutterTts.setSpeechRate(clampedRate);
    } catch (e) {
      print('TTS setSpeechRate error: $e');
    }
  }

  @override
  Future<void> setPitch(double pitch) async {
    if (!_isInitialized) return;
    
    try {
      // pitch通常在0.5-2.0之间
      final clampedPitch = pitch.clamp(0.5, 2.0);
      await _flutterTts.setPitch(clampedPitch);
    } catch (e) {
      print('TTS setPitch error: $e');
    }
  }

  @override
  Future<void> setLanguage(String locale) async {
    if (!_isInitialized) return;
    
    try {
      await _flutterTts.setLanguage(locale);
    } catch (e) {
      print('TTS setLanguage error: $e');
    }
  }

  @override
  Future<List<String>> getAvailableLanguages() async {
    if (!_isInitialized) {
      await init();
    }
    
    try {
      final languages = await _flutterTts.getLanguages;
      if (languages != null) {
        return languages.cast<String>();
      }
    } catch (e) {
      print('TTS getAvailableLanguages error: $e');
    }
    
    // 返回常见语言作为fallback
    return ['en-US', 'en-GB', 'zh-CN', 'zh-TW'];
  }

  @override
  Future<bool> isLanguageSupported(String locale) async {
    final availableLanguages = await getAvailableLanguages();
    return availableLanguages.contains(locale);
  }

  @override
  Future<bool> get isPlaying async => _isPlaying;

  @override
  Future<void> dispose() async {
    if (!_isInitialized) return;
    
    try {
      await stop();
      // FlutterTts没有dispose方法，只需要停止即可
    } catch (e) {
      print('TTS dispose error: $e');
    }
  }
}