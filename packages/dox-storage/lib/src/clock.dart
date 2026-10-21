/// Gives the current time. Inject a fixed clock in tests.
class Clock {
  const Clock();

  /// Current time in UTC.
  DateTime now() {
    return DateTime.now().toUtc();
  }
}

/// A clock that always returns the same time. Useful in tests.
class FixedClock extends Clock {
  DateTime time;

  FixedClock(DateTime time) : time = time.toUtc();

  @override
  DateTime now() {
    return time;
  }
}
