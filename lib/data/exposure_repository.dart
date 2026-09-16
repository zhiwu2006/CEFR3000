import '../models/exposure_event.dart';

/// 词条接触记录的可选仓储能力。
///
/// 独立接口让旧的内存测试替身无需立刻实现新存储，同时让正式仓储能够
/// 以稳定 ID 去重“同一会话重复展示”和“同日重复消费新词额度”。
abstract interface class ExposureRepository {
  Future<bool> recordExposure(ExposureEvent event);

  Future<bool> hasExposureForDate({
    required int wordId,
    required String localDate,
  });

  Future<List<ExposureEvent>> getExposureEvents({String? sessionId});
}
