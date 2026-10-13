import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'tts_service.dart';

/// Flutter TTS实现的发音服务
class FlutterTtsService implements TtsService {
  late FlutterTts _flutterTts;
  bool _isInitialized = false;
  Future<void>? _initializing;
  bool _isPlaying = false;

  @override
  Future<void> init({String locale = 'en-US'}) async {
    if (_isInitialized) return;
    final pending = _initializing ??= _initialize(locale);
    try {
      await pending;
    } finally {
      if (identical(_initializing, pending)) _initializing = null;
    }
  }

  Future<void> _initialize(String locale) async {
    _flutterTts = FlutterTts();

    // 使用系统默认语音引擎。不再强制 setEngine：它会让插件重新绑定引擎，
    // 随后的 setLanguage 等调用与重绑抢跑，日志里会出现
    // "not bound to TTS engine"，首个单词也可能没有声音。

    // 设置默认参数
    await _flutterTts.setLanguage(locale);
    await _flutterTts.setSpeechRate(0.5); // 0.5 是标准语速，0.44 略慢可能导致卡顿
    await _flutterTts.setVolume(1.0);
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
      debugPrint('TTS Error: $msg');
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
      debugPrint('TTS speak error: $e');
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
      debugPrint('TTS stop error: $e');
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
      debugPrint('TTS setSpeechRate error: $e');
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
      debugPrint('TTS setPitch error: $e');
    }
  }

  @override
  Future<void> setLanguage(String locale) async {
    if (!_isInitialized) return;

    try {
      await _flutterTts.setLanguage(locale);
    } catch (e) {
      debugPrint('TTS setLanguage error: $e');
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
      debugPrint('TTS getAvailableLanguages error: $e');
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
      debugPrint('TTS dispose error: $e');
    }
  }
}
