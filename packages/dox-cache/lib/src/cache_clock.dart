/// Gives the current time. Inject a fake one in tests to move time.
class CacheClock {
  const CacheClock();

  DateTime now() {
    return DateTime.now();
  }
}
