import 'dart:async';
import 'dart:io';

import 'package:dox_core/app.dart';
import 'package:dox_core/interfaces/app_config.dart';
import 'package:dox_core/router/route_data.dart';

/// The checks of `AppConfig.strict`. Each isolate has its own state.
/// `Dox().initialize` turns it on or off.
///
/// Every warning goes to stderr with a `[strict]` tag, not to the
/// logger: the logger is off by default. A warning never throws.
class StrictMode {
  StrictMode._();

  /// true when `AppConfig.strict.enabled` is on. Read on every request,
  /// so it is one static bool.
  static bool enabled = false;

  static Duration _limit = StrictConfig.defaultBlockLimit;

  /// a route warns once
  static final Set<String> _routes = <String>{};

  /// a sync `Hash` call warns once per place in the code
  static final Set<String> _hashSites = <String>{};

  /// the watchdog warns at most once in this time
  static const Duration watchdogQuiet = Duration(seconds: 10);

  static Timer? _watchdog;

  /// set the checks from [config] and forget the old warnings
  static void configure(StrictConfig config) {
    enabled = config.enabled;
    _limit = config.blockLimit;
    _routes.clear();
    _hashSites.clear();
  }

  /// warn when the sync part of the middleware and controller of [route]
  /// took longer than the limit
  static void checkHandler(RouteData route, Duration took) {
    if (took <= _limit) return;
    try {
      String name = '${route.method} ${route.path}';
      if (!_routes.add(name)) return;
      _warn(
        '$name blocked the isolate for ${took.inMilliseconds} ms (limit '
        '${_limit.inMilliseconds} ms). Other requests on this isolate had '
        'to wait. Move heavy CPU work (like bcrypt, PDF or image work) to '
        'await Dox().compute(...), and use Hash.makeAsync or '
        'Hash.verifyAsync for passwords.',
      );
    } catch (_) {
      // a warning must never break the request
    }
  }

  /// warn when a sync `Hash` method ([name], like `Hash.make`) runs in
  /// the web server. [instead] is the method to use.
  static void checkSyncHash(String name, String instead) {
    try {
      if (!Dox().isWebServer) return;
      String site = _callSite(StackTrace.current);
      if (!_hashSites.add(site)) return;
      _warn(
        '$name ran in the web server at $site. It blocks the isolate while '
        'bcrypt runs, so other requests wait. Use await $instead(...) '
        'instead.',
      );
    } catch (_) {
      // a warning must never break the request
    }
  }

  /// Start a timer that notices when the event loop of this isolate was
  /// blocked longer than the limit, also after an `await`. It can not
  /// tell which code did it. The server calls it when it listens.
  static void startWatchdog() {
    if (!enabled || _watchdog != null) return;
    Duration interval = _limit;
    int limit = _limit.inMilliseconds;
    Stopwatch clock = Stopwatch()..start();
    int last = 0;
    int quietUntil = 0;
    _watchdog = Timer.periodic(interval, (Timer timer) {
      int now = clock.elapsedMilliseconds;
      int gap = now - last;
      last = now;
      // ponytail: the check runs once per interval, so a block between
      // one and two limits long may be missed. The route check above is
      // the exact one.
      if (gap - interval.inMilliseconds <= limit || now < quietUntil) return;
      quietUntil = now + watchdogQuiet.inMilliseconds;
      _warn(
        'The event loop of isolate ${Dox().isolateId} was blocked for about '
        '$gap ms (limit $limit ms). Some code ran that long without an '
        'await, so other requests had to wait. Move heavy CPU work to '
        'await Dox().compute(...).',
      );
    });
  }

  /// stop the timer of [startWatchdog]
  static void stopWatchdog() {
    _watchdog?.cancel();
    _watchdog = null;
  }

  /// the first frame of [stack] that is not in Dox itself, like
  /// `AuthController.login (package:app/auth.dart:12:7)`
  static String _callSite(StackTrace stack) {
    for (String line in stack.toString().split('\n')) {
      if (line.isEmpty ||
          line.contains('<asynchronous suspension>') ||
          line.contains('dox_core/utils/hash.dart') ||
          line.contains('dox_core/utils/strict_mode.dart')) {
        continue;
      }
      return line.replaceFirst(_frameNumber, '').trim();
    }
    return 'an unknown place';
  }

  static final RegExp _frameNumber = RegExp(r'^#\d+\s+');

  static void _warn(String text) {
    try {
      stderr.writeln('[strict] $text');
    } catch (_) {
      // a warning must never break the request
    }
  }
}
