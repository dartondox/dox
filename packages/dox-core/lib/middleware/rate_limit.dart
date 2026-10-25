import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:dox_cache/dox_cache.dart' show CacheConstants, MemoryDriver;
import 'package:dox_core/dox_core.dart';

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
/// The counts live in the cache. When the default cache store of the app
/// is Redis, the counts are shared by all isolates and servers. Else they
/// live in memory, in each isolate.
///
/// It is a fixed window: the counter starts again at each new window
/// (eg. each new minute). So a client can send up to 2 x [max] requests
/// around the end of one window and the start of the next.
// ponytail: fixed window, a sliding window if the burst at the edge matters
class RateLimit implements IDoxMiddleware {
  RateLimit({
    this.max = 60,
    this.per = const Duration(minutes: 1),
    RateLimitKey? key,
    String? name,
    this.store,
    this.cacheStore,
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

  final DateTime Function() _now;

  /// one memory store per isolate for every limit without Redis
  static final CacheStore _memory = CacheStore(MemoryDriver());

  static String _byIp(DoxRequest req) => req.ip();

  @override
  Future<dynamic> handle(IDoxRequest req) async {
    DoxRequest request = req as DoxRequest;
    int window = per.inMilliseconds;
    int now = _now().millisecondsSinceEpoch;
    int index = now ~/ window;
    String cacheKey = 'rate_limit:$name:${key(request)}:$index';

    CacheStore counts = _counts();
    // the ttl is one full window, so the key is gone after its window
    await counts.add(cacheKey, 0, per);
    int hits = await counts.increment(cacheKey);

    HttpHeaders headers = req.httpRequest.response.headers;
    headers.set('X-RateLimit-Limit', max);
    headers.set('X-RateLimit-Remaining', math.max(0, max - hits));
    if (hits <= max) return req;

    int waitMs = (index + 1) * window - now;
    headers.set(HttpHeaders.retryAfterHeader, (waitMs / 1000).ceil());
    throw TooManyRequestsException();
  }

  CacheStore _counts() {
    CacheStore? given = cacheStore;
    if (given != null) return given;
    String? storeName = store;
    if (storeName != null) return Dox().cache.store(storeName);
    CacheConfig config = Dox().config.cache;
    Object? driver = config.stores[config.defaultStore]?['driver'];
    if (driver == CacheConstants.redisDriver) return Dox().cache.store();
    return _memory;
  }
}
