import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:dox_cache/dox_cache.dart' show CacheConstants;
import 'package:dox_core/dox_core.dart';
import 'package:dox_core/isolate/port_calls.dart';

/// Session data of the `cache` driver on a `memory` cache store.
///
/// A memory store lives inside one isolate. The server runs one isolate
/// per CPU core, so a session saved by one isolate would be missing in
/// the next request on another isolate. So the data of these sessions
/// lives in the memory store of the main isolate. The other isolates
/// read and write it through a [SendPort]: one message per session read,
/// and one per changed session.
///
/// The main isolate uses its own memory store as it is, so expired
/// sessions are removed the same way (on read, and by the sweep of the
/// memory driver). In the main isolate, and in an app with one isolate,
/// nothing changes: the store is used in place, with no message.
///
/// The session id and the data are never logged here.
class SessionMemoryStore {
  SessionMemoryStore._();

  /// one per isolate
  static final SessionMemoryStore instance = SessionMemoryStore._();

  /// the most time to wait for the main isolate
  static const Duration timeout = Duration(seconds: 5);

  ReceivePort? _server;

  /// the main isolate, null in the main isolate itself
  SendPort? _owner;
  final PortCalls _calls = PortCalls(timeout);

  /// True when the store [name] (null: the default store) of
  /// `AppConfig.cache` uses the memory driver.
  static bool isMemory(String? name) {
    CacheConfig config = Dox().config.cache;
    Object? driver = config.stores[name ?? config.defaultStore]?['driver'];
    return driver == CacheConstants.memoryDriver;
  }

  /// The port the other isolates send to. Opened on the first call, in
  /// the main isolate.
  SendPort get port {
    ReceivePort server = _server ??= ReceivePort()..listen(_serve);
    return server.sendPort;
  }

  /// use the store of the isolate that owns [owner] (a [port]) from now
  /// on. null uses the store of this isolate.
  void connect(SendPort? owner) {
    _owner = owner;
  }

  /// the value of [key] in the store [store], or null
  Future<Object?> get(String? store, String key) {
    return _call(<Object?>[0, store, key]);
  }

  /// Stores [value] (it must be JSON) under [key] for [ttl].
  Future<void> put(String? store, String key, Object? value, Duration ttl) {
    if (_owner == null) return Dox().cache.store(store).put(key, value, ttl);
    // encode here, so a value that is not JSON fails in this isolate
    return _call(<Object?>[
      1,
      store,
      key,
      jsonEncode(value),
      ttl.inMicroseconds,
    ]);
  }

  /// removes [key] from the store [store]
  Future<void> forget(String? store, String key) {
    return _call(<Object?>[2, store, key]);
  }

  /// close the ports
  void close() {
    _server?.close();
    _server = null;
    _calls.close();
    _owner = null;
  }

  Future<Object?> _call(List<Object?> message) {
    SendPort? owner = _owner;
    if (owner == null) return _run(message);
    return _calls.send(owner, message);
  }

  void _serve(dynamic message) {
    PortCalls.answer(message, _run);
  }

  static Future<Object?> _run(List<Object?> m) async {
    CacheStore store = Dox().cache.store(m[1] as String?);
    String key = m[2] as String;
    switch (m[0]) {
      case 0:
        return store.get(key);
      case 1:
        Duration ttl = Duration(microseconds: m[4] as int);
        await store.put(key, jsonDecode(m[3] as String), ttl);
        return null;
      default:
        await store.forget(key);
        return null;
    }
  }
}
