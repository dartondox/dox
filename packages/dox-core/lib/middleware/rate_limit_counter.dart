import 'dart:async';
import 'dart:isolate';

import 'package:dox_core/isolate/port_calls.dart';

/// Rate limit counts shared by all isolates of the app.
///
/// The main isolate owns the counts. The other isolates send each
/// increment to it through a [SendPort] and wait for the new count.
/// [incrementAndRead] also reads a second key in the same message.
/// `DoxIsolate` gives every isolate it starts the [port] of the main
/// isolate, and the isolate calls [connect] with it.
///
/// In the main isolate (and in an app with one isolate) the count is
/// made in place, with no message.
class RateLimitCounter {
  RateLimitCounter._();

  /// one per isolate
  static final RateLimitCounter instance = RateLimitCounter._();

  /// the most time to wait for the main isolate. After it, the count is
  /// made in this isolate, so a request never hangs (eg. during shutdown).
  static const Duration timeout = Duration(seconds: 5);

  /// The most keys the counter keeps. One key is about 150 bytes, so
  /// this is about 15 MB. Without a cap, a client that sends from many
  /// ips (an IPv6 /64 has 2^64) could grow the map with no end.
  static const int defaultMaxKeys = 100000;

  /// see [defaultMaxKeys]; null is no cap. Only changed in tests.
  int? maxKeys = defaultMaxKeys;

  /// key => count, only used in the isolate that owns the counts.
  /// A Dart map keeps insert order, so the first key is the oldest.
  final Map<String, _Count> _counts = <String, _Count>{};
  int _nextSweep = 0;
  ReceivePort? _server;

  /// the owner of the counts, null in the owner itself
  SendPort? _owner;
  final PortCalls _calls = PortCalls(timeout);

  /// number of keys kept now, for tests
  int get length => _counts.length;

  /// the calls to the owner, for tests
  PortCalls get calls => _calls;

  /// The port other isolates send their increments to. Opened on the
  /// first call, in the isolate that owns the counts (the main isolate).
  SendPort get port {
    ReceivePort server = _server ??= ReceivePort()..listen(_serve);
    return server.sendPort;
  }

  /// count in the isolate that owns [owner] (a [port]) from now on.
  /// null counts in this isolate.
  void connect(SendPort? owner) {
    _owner = owner;
  }

  /// Adds one to [key] and gives the new count. A new key, or a key
  /// older than [ttl], starts at 1.
  Future<int> increment(String key, Duration ttl) async {
    List<int> counts = await _send(key, ttl.inMilliseconds, null);
    return counts[0];
  }

  /// Adds one to [key] and also reads [other] with no change to it.
  /// Gives the new count of [key] and the count of [other] (0 when it
  /// is missing or older than its ttl). It is one message to the owner.
  Future<(int, int)> incrementAndRead(
    String key,
    String other,
    Duration ttl,
  ) async {
    List<int> counts = await _send(key, ttl.inMilliseconds, other);
    return (counts[0], counts[1]);
  }

  Future<List<int>> _send(String key, int ttlMs, String? other) async {
    SendPort? owner = _owner;
    if (owner == null) return _run(key, ttlMs, other);
    try {
      // from another isolate group a list arrives as `List<dynamic>`
      Object? counts = await _calls.send(owner, <Object?>[key, ttlMs, other]);
      if (counts is List<int>) return counts;
      return List<int>.of((counts as List<Object?>).cast<int>());
    } on Object {
      // no answer in time (eg. during shutdown): count here, so a
      // request never hangs
      return _run(key, ttlMs, other);
    }
  }

  /// close the ports and forget all counts
  void close() {
    _server?.close();
    _server = null;
    _calls.close();
    _owner = null;
    _counts.clear();
    _nextSweep = 0;
  }

  void _serve(dynamic message) {
    PortCalls.answer(message, _runMessage);
  }

  List<int> _runMessage(List<Object?> m) {
    return _run(m[0] as String, m[1] as int, m[2] as String?);
  }

  /// the new count of [key], then the count of [other] when given
  List<int> _run(String key, int ttlMs, String? other) {
    int hits = _increment(key, ttlMs);
    if (other == null) return <int>[hits];
    _Count? count = _counts[other];
    int now = DateTime.now().millisecondsSinceEpoch;
    if (count == null || count.expiresAt <= now) return <int>[hits, 0];
    return <int>[hits, count.hits];
  }

  int _increment(String key, int ttlMs) {
    int now = DateTime.now().millisecondsSinceEpoch;
    // drop old keys at most once a second, so the map does not grow.
    // ponytail: a full scan, at most [maxKeys] keys (about 1 ms) once a
    // second. Keep keys per ttl in order if this ever shows up.
    if (now >= _nextSweep) _sweep(now);
    _Count? count = _counts[key];
    if (count == null || count.expiresAt <= now) {
      int? limit = maxKeys;
      if (count == null && limit != null && _counts.length >= limit) {
        _makeRoom(now, limit);
      }
      count = _Count(now + ttlMs);
      // remove first, so a key of a new window moves to the end (newest)
      _counts.remove(key);
      _counts[key] = count;
    }
    return ++count.hits;
  }

  void _sweep(int now) {
    _counts.removeWhere((String _, _Count c) => c.expiresAt <= now);
    _nextSweep = now + 1000;
  }

  /// The map is full. Drop the expired keys. When that frees less than
  /// a tenth of the map, drop the oldest keys until a tenth is free. So
  /// this full scan runs at most once per [limit] / 10 new keys.
  ///
  /// Dropping the oldest keys gives those clients a fresh count. That
  /// is safer than turning new clients away: a client with many ips
  /// can fill the map, and then it would lock out every new user.
  void _makeRoom(int now, int limit) {
    _sweep(now);
    int drop = _counts.length - (limit - limit ~/ 10 - 1);
    if (drop <= 0) return;
    List<String> oldest = _counts.keys.take(drop).toList();
    for (String key in oldest) {
      _counts.remove(key);
    }
  }
}

class _Count {
  _Count(this.expiresAt);

  final int expiresAt;
  int hits = 0;
}
