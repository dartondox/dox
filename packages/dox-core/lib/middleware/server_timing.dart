import 'dart:async';

import 'package:dox_core/dox_core.dart';

/// Adds a `Server-Timing` header to the answer. The browser dev tools
/// show it in the Network tab.
///
/// ```
/// AppConfig(
///   globalMiddleware: <dynamic>[
///     if (Env.get<String>('APP_ENV') == 'development') const ServerTiming(),
///   ],
/// );
/// ```
///
/// It always sends `total` (the middleware after it and the controller)
/// and `handler` (only the controller). Other code adds its own timing
/// to the current request with [add] or [measure]. The names `total`
/// and `handler` are kept for these two: your own `total` is sent as
/// `app_total`, and your own `handler` as `app_handler`. A time you
/// name `app_total` yourself is added to it.
///
/// ```
/// ServerTiming.add('db', query.duration);
/// String html = await ServerTiming.measure('render', () => view.render());
/// ```
///
/// The names come in the order they were first added. So the times of
/// the controller (like `db`) come first, then `handler`, then `total`:
/// `db;dur=4.10;desc="3 calls", handler;dur=12.34, total;dur=13.02`.
///
/// When the answer already has a `Server-Timing` header (set with
/// `res.header`), these times are added after it.
///
/// Security: this header tells every client how long your code takes.
/// That can help an attacker (for example to guess if a user exists).
/// It is off unless you add it. Use it in development, or only for
/// clients you trust.
class ServerTiming implements IDoxNextMiddleware {
  const ServerTiming();

  /// the header name
  static const String header = 'Server-Timing';

  /// the zone key that holds the timings of the current request.
  /// A private object, so no other code can set or read it.
  static final Object _key = Object();

  /// at most this many names in one header (plus `handler` and
  /// `total`), so a loop that makes new names can not make a huge header
  static const int maxNames = 32;

  @override
  Future<DoxResponse> handle(DoxRequest req, Next next) async {
    _Timings timings = _Timings();
    Stopwatch watch = Stopwatch()..start();
    DoxResponse res = await runZoned(
      next,
      zoneValues: <Object, Object>{_key: timings},
    );
    timings.add('total', watch.elapsed, null, own: true);
    String value = timings.toHeader();
    // keep a Server-Timing header that the app set itself
    String key = header;
    for (MapEntry<String, dynamic> entry in res.headers.entries) {
      if (entry.key.toLowerCase() == 'server-timing') {
        key = entry.key;
        Object? old = entry.value;
        String text = old is Iterable ? old.join(', ') : '$old';
        if (text.isNotEmpty) value = '$text, $value';
      }
    }
    return res.header(key, value);
  }

  /// Adds [duration] to the timing [name] of the current request. When
  /// the same name is added again, the times are summed and counted.
  ///
  /// It does nothing outside a request, or when the [ServerTiming]
  /// middleware is not on. Then it costs one zone lookup.
  ///
  /// [name] is cleaned to a valid token: other characters become `_`.
  /// An empty name is ignored. [description] is shown next to the time.
  static void add(String name, Duration duration, {String? description}) {
    Object? timings = Zone.current[_key];
    if (timings is _Timings) timings.add(name, duration, description);
  }

  /// Runs [fn] and adds the time it took as [name], also when it
  /// throws. Without the middleware it only runs [fn].
  static Future<T> measure<T>(String name, FutureOr<T> Function() fn) async {
    Object? timings = Zone.current[_key];
    if (timings is! _Timings) return await fn();
    Stopwatch watch = Stopwatch()..start();
    try {
      return await fn();
    } finally {
      timings.add(name, watch.elapsed, null);
    }
  }
}

/// Not exported. true when the [ServerTiming] middleware is on for the
/// current request. The router checks it before it times the controller,
/// so a route without the middleware pays nothing more.
bool serverTimingOn() {
  return Zone.current[ServerTiming._key] is _Timings;
}

/// Not exported. Runs the controller [fn] and adds its time as
/// `handler`, also when it throws. Call it only when [serverTimingOn].
Future<dynamic> timeHandler(FutureOr<dynamic> Function() fn) async {
  _Timings timings = Zone.current[ServerTiming._key] as _Timings;
  Stopwatch watch = Stopwatch()..start();
  try {
    return await fn();
  } finally {
    timings.add('handler', watch.elapsed, null, own: true);
  }
}

/// one name in the header
class _Timing {
  int micros = 0;
  int count = 0;
  String? description;
}

/// the timings of one request, in the order they were first added
class _Timings {
  final Map<String, _Timing> _items = <String, _Timing>{};

  /// characters other than a `token` (RFC 9110)
  static final RegExp _notToken = RegExp(r"[^A-Za-z0-9!#$%&'*+.^_`|~-]");

  /// control and non-ASCII characters, not safe in a header value
  static final RegExp _notPrintable = RegExp(r'[^\x20-\x7e]');

  /// [own] is true only for the built-in `total` and `handler`. A name
  /// from app code that is `total` or `handler` gets `app_` in front,
  /// so it does not add to the built-in times.
  void add(
    String name,
    Duration duration,
    String? description, {
    bool own = false,
  }) {
    String clean = name.replaceAll(_notToken, '_');
    if (clean.isEmpty) return;
    if (clean.length > 64) clean = clean.substring(0, 64);
    if (!own && (clean == 'total' || clean == 'handler')) clean = 'app_$clean';
    _Timing? item = _items[clean];
    if (item == null) {
      if (!own && _items.length >= ServerTiming.maxNames) return;
      item = _items[clean] = _Timing();
    }
    item.micros += duration.inMicroseconds;
    item.count++;
    if (description != null) item.description = description;
  }

  String toHeader() {
    List<String> parts = <String>[];
    _items.forEach((String name, _Timing item) {
      String part = '$name;dur=${(item.micros / 1000).toStringAsFixed(2)}';
      String? desc = item.description;
      if (desc == null && item.count > 1) desc = '${item.count} calls';
      if (desc != null) part += ';desc=${_quote(desc)}';
      parts.add(part);
    });
    return parts.join(', ');
  }

  /// a quoted-string: printable ASCII only, `\` and `"` escaped
  static String _quote(String value) {
    String safe = value.replaceAll(_notPrintable, '');
    if (safe.length > 200) safe = safe.substring(0, 200);
    safe = safe.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
    return '"$safe"';
  }
}
