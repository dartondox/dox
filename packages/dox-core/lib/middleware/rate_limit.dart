import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:dox_cache/dox_cache.dart' show CacheConstants, RedisDriver;
import 'package:dox_core/dox_core.dart';
import 'package:dox_core/middleware/rate_limit_counter.dart';

/// Gives the name of the client to count requests for, eg. its ip.
typedef RateLimitKey = String Function(DoxRequest req);

/// Lets a client send at most [max] requests in each [per] window.
/// One more request gets `429 Too Many Requests` with a `Retry-After`
/// header (seconds). Every answer has `X-RateLimit-Limit` and
/// `X-RateLimit-Remaining`.
///
/// ```
/// Route.post('/login', <dynamic>[
///   RateLimit(max: 5, per: Duration(minutes: 1)),
///   authController.login,
/// ]);
/// ```
///
/// Where the counts live:
/// - the default cache store is Redis: in Redis. All isolates and all
///   servers share them.
/// - else: in the main isolate. All isolates of this server share them.
///   The other isolates send each count to the main isolate (one message
///   and its answer per limited request). Each server has its own counts.
/// - [store] names a store: in that store (a `memory` store counts in
///   the main isolate, like above).
/// - [cacheStore] is given: in that store, as it is. A `MemoryDriver`
///   store given here counts in each isolate on its own.
///
/// By default it is a fixed window: the counter starts again at each
/// new window (eg. each new minute). So a client can send up to
/// 2 x [max] requests around the end of one window and the start of
/// the next. Set [sliding] to stop that burst.
///
/// A blocked request still counts. So a client that keeps sending while
/// it is blocked stays blocked.
class RateLimit implements IDoxMiddleware {
  RateLimit({
    this.max = 60,
    this.per = const Duration(minutes: 1),
    RateLimitKey? key,
    String? name,
    this.store,
    this.cacheStore,
    this.sliding = false,
    DateTime Function()? now,
  }) : key = key ?? _byIp,
       name = name ?? '${max}_${per.inMilliseconds}',
       _now = now ?? DateTime.now {
    if (max < 1) throw ArgumentError.value(max, 'max', 'must be 1 or more');
    if (per.inMilliseconds < 1) {
      throw ArgumentError.value(per, 'per', 'must be 1 ms or more');
    }
  }

  /// the most requests in one window
  final int max;

  /// the length of one window
  final Duration per;

  /// the client to count for. Default is the client ip. With
  /// `CoreFlags.rateLimitIpv6Prefix` an IPv6 client counts by its /64,
  /// see [ipBucket].
  final RateLimitKey key;

  /// Two limits with the same name (and the same key) share one counter.
  /// Default is made from [max] and [per].
  final String name;

  /// the name of a cache store from `AppConfig.cache` to keep the counts.
  /// Default: the default store when it is Redis, else memory.
  final String? store;

  /// a ready cache store to keep the counts, eg. in tests
  final CacheStore? cacheStore;

  /// Use a sliding window. The count is then a guess of the requests in
  /// the last [per]: the count of this window plus a part of the count
  /// of the window before. That part gets smaller as this window goes
  /// on. Eg. 30% into this window, 70% of the last count is added.
  /// It stops the burst of 2 x [max] at the edge of a window. It costs
  /// one more read per request, and each count is kept for 2 windows.
  ///
  /// `Retry-After` is the time until one more request fits, if the
  /// client sends nothing in between.
  final bool sliding;

  final DateTime Function() _now;

  /// the default [key]: the client ip (after `trustedProxies`), see
  /// [ipBucket]
  static String _byIp(DoxRequest req) {
    String ip = req.ip();
    return Dox().flags.rateLimitIpv6Prefix ? ipBucket(ip) : ip;
  }

  /// The count key of [ip] with `CoreFlags.rateLimitIpv6Prefix`:
  /// - an IPv6 address gives its /64 prefix, eg. `2001:db8:1:2::/64`.
  ///   One home or one server gets a whole /64, so a client can not get
  ///   a new count by changing the last 64 bits.
  /// - an IPv4-mapped IPv6 address (`::ffff:1.2.3.4`) gives the IPv4
  ///   address (`1.2.3.4`).
  /// - an IPv4 address, or a value that is not an ip, stays as it is.
  /// ```
  /// RateLimit(key: (DoxRequest req) => RateLimit.ipBucket(req.ip()));
  /// ```
  static String ipBucket(String ip) {
    if (!ip.contains(':')) return ip;
    int zone = ip.indexOf('%');
    List<int> bytes;
    try {
      bytes = Uri.parseIPv6Address(zone < 0 ? ip : ip.substring(0, zone));
    } on FormatException {
      return ip;
    }
    bool mapped = bytes[10] == 0xff && bytes[11] == 0xff;
    for (int i = 0; mapped && i < 10; i++) {
      mapped = bytes[i] == 0;
    }
    if (mapped) return bytes.sublist(12).join('.');
    StringBuffer out = StringBuffer();
    for (int i = 0; i < 8; i += 2) {
      out
        ..write(((bytes[i] << 8) | bytes[i + 1]).toRadixString(16))
        ..write(':');
    }
    out.write(':/64');
    return out.toString();
  }

  @override
  Future<dynamic> handle(IDoxRequest req) async {
    DoxRequest request = req as DoxRequest;
    int window = per.inMilliseconds;
    int now = _now().millisecondsSinceEpoch;
    int index = now ~/ window;
    String client = key(request);
    String cacheKey = 'rate_limit:$name:$client:$index';

    if (sliding) return _sliding(request, window, now, index, client);

    // the ttl is one full window, so the key is gone after its window
    CacheStore? counts = _cacheStore();
    int hits;
    if (counts == null) {
      hits = await RateLimitCounter.instance.increment(cacheKey, per);
    } else if (counts.driver is RedisDriver) {
      hits = await _countOnRedis(counts, cacheKey, per);
    } else {
      await counts.add(cacheKey, 0, per);
      hits = await counts.increment(cacheKey);
    }

    HttpHeaders headers = req.httpRequest.response.headers;
    headers.set('X-RateLimit-Limit', max);
    headers.set('X-RateLimit-Remaining', math.max(0, max - hits));
    if (hits <= max) return req;

    int waitMs = (index + 1) * window - now;
    headers.set(HttpHeaders.retryAfterHeader, (waitMs / 1000).ceil());
    throw TooManyRequestsException();
  }

  /// The sliding window. All math is in ms x hits, so it stays in ints:
  /// `estimate x window = before x (window - elapsed) + hits x window`.
  Future<dynamic> _sliding(
    DoxRequest req,
    int window,
    int now,
    int index,
    String client,
  ) async {
    String cacheKey = 'rate_limit:$name:$client:$index';
    String beforeKey = 'rate_limit:$name:$client:${index - 1}';
    // the ttl is two windows, so the key can still be read in the next
    // window as the window before
    Duration ttl = per * 2;
    CacheStore? counts = _cacheStore();
    int hits;
    int before;
    if (counts == null) {
      (hits, before) = await RateLimitCounter.instance.incrementAndRead(
        cacheKey,
        beforeKey,
        ttl,
      );
    } else if (counts.driver is RedisDriver) {
      // started in the same tick as the count: one round trip
      Future<int> counted = _countOnRedis(counts, cacheKey, ttl);
      Future<Object?> read = counts.get(beforeKey)..ignore();
      hits = await counted;
      before = ((await read) as num?)?.toInt() ?? 0;
    } else {
      // other stores (eg. file) may run the steps out of order when they
      // run at the same time, so one after the other
      await counts.add(cacheKey, 0, ttl);
      hits = await counts.increment(cacheKey);
      before = ((await counts.get(beforeKey)) as num?)?.toInt() ?? 0;
    }

    int elapsed = now - index * window;
    int estimate = before * (window - elapsed) + hits * window;
    HttpHeaders headers = req.httpRequest.response.headers;
    headers.set('X-RateLimit-Limit', max);
    int used = (estimate + window - 1) ~/ window;
    headers.set('X-RateLimit-Remaining', math.max(0, max - used));
    if (estimate <= max * window) return req;

    // The next request fits when its own hit fits too. While this window
    // has room (hits < max), wait until the part of the window before
    // is small enough. Else wait for the next window, where these hits
    // become the window before.
    int waitMs;
    if (hits < max) {
      int fitsAt = window - (max - 1 - hits) * window ~/ before;
      waitMs = fitsAt - elapsed;
    } else {
      int fitsAt = window - (max - 1) * window ~/ hits;
      waitMs = window - elapsed + fitsAt;
    }
    headers.set(
      HttpHeaders.retryAfterHeader,
      math.max(1, (waitMs / 1000).ceil()),
    );
    throw TooManyRequestsException();
  }

  /// Adds one to [key] on Redis and gives the new count. The add (with
  /// the ttl) and the increment start in the same tick, so ioredis sends
  /// them in one write: one round trip.
  ///
  /// It does not trust the order. When the increment made the key (the
  /// add ran late or failed), the key has no ttl, so it is set here. Else
  /// the count would never end and the client would stay blocked. This
  /// costs one more round trip, only in that case. An error of the add is
  /// thrown, the same as when the steps ran one after the other.
  static Future<int> _countOnRedis(
    CacheStore counts,
    String key,
    Duration ttl,
  ) async {
    Future<bool> adding = counts.add(key, 0, ttl)..ignore();
    Future<int> counting = counts.increment(key)..ignore();
    bool added = false;
    Object? addError;
    StackTrace? addTrace;
    try {
      added = await adding;
    } catch (error, trace) {
      addError = error;
      addTrace = trace;
    }
    int hits;
    try {
      hits = await counting;
    } catch (_) {
      if (addError != null) Error.throwWithStackTrace(addError, addTrace!);
      rethrow;
    }
    if (hits == 1 && !added) await _setTtl(counts, key, ttl);
    if (addError != null) Error.throwWithStackTrace(addError, addTrace!);
    return hits;
  }

  /// Sets the ttl of a count that has none. Tries twice.
  ///
  /// ponytail: only the request that made the key (count 1) can see that
  /// it has no ttl. When both tries fail, the key stays with no ttl and
  /// later requests (count above 1) do not repair it: that would cost a
  /// TTL read on every request. Delete the key by hand if it happens.
  static Future<void> _setTtl(
    CacheStore counts,
    String key,
    Duration ttl,
  ) async {
    try {
      await counts.touch(key, ttl);
    } catch (_) {
      await counts.touch(key, ttl);
    }
  }

  /// the cache store that keeps the counts, or null for the counts of
  /// the main isolate ([RateLimitCounter]).
  CacheStore? _cacheStore() {
    CacheStore? given = cacheStore;
    if (given != null) return given;
    CacheConfig config = Dox().config.cache;
    String? storeName = store;
    if (storeName != null) {
      Object? driver = config.stores[storeName]?['driver'];
      if (driver == CacheConstants.memoryDriver) return null;
      return Dox().cache.store(storeName);
    }
    Object? driver = config.stores[config.defaultStore]?['driver'];
    if (driver == CacheConstants.redisDriver) return Dox().cache.store();
    return null;
  }
}
