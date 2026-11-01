import 'dart:async';
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

  /// Free the lock, whoever holds it. True when it was there.
  /// Drivers without this throw [UnsupportedError].
  Future<bool> forceRelease() {
    throw UnsupportedError('$runtimeType does not support forceRelease');
  }

  /// Try to take the lock until [timeout] passes.
  ///
  /// Without [callback]: true when taken, false when the time is over.
  /// You must call [release] yourself.
  ///
  /// With [callback]: runs it while holding the lock, frees the lock
  /// and returns the callback result. Throws [LockTimeoutException]
  /// when the lock was not taken in time.
  /// ```
  /// int count = await lock.block(Duration(seconds: 5), () => work());
  /// ```
  Future<T> block<T>(
    Duration timeout, [
    FutureOr<T> Function()? callback,
  ]) async {
    bool taken = await _waitFor(timeout);
    if (callback == null) {
      return taken as T;
    }
    if (!taken) {
      throw LockTimeoutException(name, timeout);
    }
    try {
      return await callback();
    } finally {
      await release();
    }
  }

  Future<bool> _waitFor(Duration timeout) async {
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

/// Thrown by [CacheLock.block] with a callback when the lock was not
/// taken in time.
class LockTimeoutException implements Exception {
  LockTimeoutException(this.name, this.timeout);

  /// Lock name.
  final String name;

  /// How long it waited.
  final Duration timeout;

  @override
  String toString() {
    return 'LockTimeoutException: lock "$name" was not free after $timeout';
  }
}
