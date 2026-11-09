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
/// to the current request with [add] or [measure]:
///
/// ```
/// ServerTiming.add('db', query.duration);
/// String html = await ServerTiming.measure('render', () => view.render());
/// ```
///
/// The header is sent like this:
/// `handler;dur=12.34, db;dur=4.10;desc="3 calls", total;dur=13.02`.
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
    timings.add('total', watch.elapsed, null);
    return res.header(header, timings.toHeader());
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

  void add(String name, Duration duration, String? description) {
    String clean = name.replaceAll(_notToken, '_');
    if (clean.isEmpty) return;
    if (clean.length > 64) clean = clean.substring(0, 64);
    _Timing? item = _items[clean];
    if (item == null) {
      bool own = clean == 'total' || clean == 'handler';
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
