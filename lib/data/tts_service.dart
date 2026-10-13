/// TTS服务接口
abstract class TtsService {
  /// 初始化TTS服务
  Future<void> init({String locale = 'en-US'});

  /// 发音
  Future<void> speak(String text);

  /// 停止发音
  Future<void> stop();

  /// 设置语速
  Future<void> setSpeechRate(double rate);

  /// 设置音调
  Future<void> setPitch(double pitch);

  /// 设置语言
  Future<void> setLanguage(String locale);

  /// 获取可用语言列表
  Future<List<String>> getAvailableLanguages();

  /// 检查是否支持指定语言
  Future<bool> isLanguageSupported(String locale);

  /// 获取当前状态
  Future<bool> get isPlaying;

  /// 释放资源
  Future<void> dispose();
}
