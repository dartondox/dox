import 'dart:math';

import 'constants/cache_constants.dart';

/// An atomic lock. Only one owner can hold it at a time.
///
/// ```
/// CacheLock lock = cache.lock('report', Duration(seconds: 10));
/// if (await lock.get()) {
///   try { ... } finally { await lock.release(); }
/// }
/// ```
abstract class CacheLock {
  CacheLock(this.name, this.ttl, [String? owner])
    : owner = owner ?? randomOwner();

  /// Lock name.
  final String name;

  /// Lock is freed after this time even if not released. Null means never.
  final Duration? ttl;

  /// Random token of this owner. Pass it to `lock()` in another process
  /// to release the same lock there.
  final String owner;

  /// Try to take the lock once. True when taken.
  Future<bool> get();

  /// Free the lock if this owner holds it. True when freed.
  Future<bool> release();

  /// Try to take the lock until [timeout] passes. True when taken.
  Future<bool> block(Duration timeout) async {
    Stopwatch watch = Stopwatch()..start();
    while (true) {
      if (await get()) {
        return true;
      }
      if (watch.elapsed >= timeout) {
        return false;
      }
      await Future<void>.delayed(CacheConstants.lockPollInterval);
    }
  }

  /// One secure random source for all tokens.
  static final Random _random = Random.secure();

  /// A random hex token.
  static String randomOwner() {
    Random random = _random;
    StringBuffer buffer = StringBuffer();
    for (int i = 0; i < 16; i++) {
      buffer.write(random.nextInt(256).toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }
}
