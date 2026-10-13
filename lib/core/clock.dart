/// 可注入的时间来源。
///
/// 学习调度、每日边界和生命周期恢复都必须使用同一个时间来源，
/// 这样领域测试无需修改系统时钟，也不会把暂停时间误算为作答时间。
abstract interface class Clock {
  DateTime get now;
}

class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime get now => DateTime.now();
}

class FixedClock implements Clock {
  DateTime _value;

  FixedClock(this._value);

  @override
  DateTime get now => _value;

  void set(DateTime value) => _value = value;
}
