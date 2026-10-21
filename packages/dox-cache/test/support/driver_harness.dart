import 'package:dox_cache/dox_cache.dart';

/// Builds one driver for the shared contract tests.
abstract class DriverHarness {
  String get name;

  /// True when the driver supports locks.
  bool get supportsLocks;

  /// A fresh, empty driver.
  Future<CacheDriver> create();

  /// Move time forward (fake clock, or a real wait for Redis).
  Future<void> advance(Duration duration);

  /// Clean up after one test.
  Future<void> close();
}
