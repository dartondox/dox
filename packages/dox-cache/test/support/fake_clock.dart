import 'package:dox_cache/dox_cache.dart';

/// A clock that only moves when told.
class FakeClock extends CacheClock {
  FakeClock([DateTime? start]) : _now = start ?? DateTime(2026);

  DateTime _now;

  @override
  DateTime now() {
    return _now;
  }

  void advance(Duration duration) {
    _now = _now.add(duration);
  }
}
