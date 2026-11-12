import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:dox_cache/dox_cache.dart' show CacheConstants;
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

  /// the client to count for. Default is the client ip.
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

  static String _byIp(DoxRequest req) => req.ip();

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
    } else {
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
