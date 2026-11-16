import 'dart:async';
import 'dart:io';

import 'package:dox_core/dox_core.dart';

/// Runs work after the response is sent, so the client does not wait
/// for it. Any code can add work. It does not need the request.
///
/// It is off by default. Turn it on once in each isolate, for example
/// in the `setup()` of a provider. Then add work from a controller, a
/// service or a package:
///
/// ```
/// AfterResponse.enable();
/// AfterResponse.run(() => mailer.sendWelcome(user));
/// ```
///
/// - The work of one request runs after the response of that request
///   is sent, one after the other, in the order it was added. The next
///   one starts only when the one before it ends, so work that never
///   ends blocks the rest of the work of that request. It also keeps
///   the upload temp files of that request for ever, as they are deleted
///   after the work.
/// - Outside a request, or when it is off, the work runs soon, after
///   the code that is running now.
/// - An error in the work is reported to the exception handler. It
///   never reaches the client and never stops the server.
/// - The work is not kept anywhere. When the server stops, work that
///   did not run yet is lost. Use a queue for work that must run.
class AfterResponse {
  AfterResponse._();

  /// the zone key that holds the work of the current request.
  /// A private object, so no other code can set or read it.
  static final Object _key = Object();

  static bool _enabled = false;

  /// true after [enable] in this isolate
  static bool get enabled => _enabled;

  /// Turn it on in this isolate. Each request then runs in its own
  /// zone, so [run] knows which response to wait for.
  static void enable() => _enabled = true;

  /// Turn it off in this isolate. For tests.
  static void disable() => _enabled = false;

  /// Runs [work] after the response of the current request is sent.
  /// Outside a request, or when it is off, [work] runs soon.
  static void run(FutureOr<void> Function() work) {
    Object? pending = Zone.current[_key];
    if (pending is _Pending && !pending.sent) {
      pending.add(work);
    } else {
      Timer.run(() => _call(work));
    }
  }

  /// Internal: the request handler calls it when it is on. Runs
  /// [handle] in a zone of its own, then the work after [res] is sent.
  /// The work list and the wait for [res] are made on the first [run],
  /// so a request that adds no work pays only for the zone.
  static void wrap(HttpResponse res, void Function() handle) {
    runZoned(handle, zoneValues: <Object, Object>{_key: _Pending(res)});
  }

  /// Internal: the request handler calls it when the middleware and the
  /// controller of the current request have ended. The work waits for it,
  /// so a client that leaves early does not start it while the handler
  /// still runs.
  static void handlerEnded() {
    Object? pending = Zone.current[_key];
    if (pending is _Pending) pending.end();
  }

  /// Internal: ends when the work of the current request has run.
  /// Done at once when there was no work.
  static Future<void> flushed() {
    Object? pending = Zone.current[_key];
    return (pending is _Pending ? pending._flushed : null) ??
        Future<void>.value();
  }

  static Future<void> _call(FutureOr<void> Function() work) async {
    try {
      await work();
    } catch (error, stackTrace) {
      try {
        Dox().config.exceptionHandler.report(error, stackTrace);
      } catch (_) {
        Logger.danger(
          'after response work failed: $error\n$stackTrace',
          null,
          'error',
        );
      }
    }
  }
}

/// the work of one request
class _Pending {
  _Pending(this._res);

  final HttpResponse _res;

  /// null until the first work is added
  List<FutureOr<void> Function()>? _work;

  /// true once the response is sent. work added later runs soon.
  bool sent = false;

  /// ends when the work has run. null until the first work is added.
  Future<void>? _flushed;

  /// true once the middleware and the controller have ended
  bool _ended = false;
  Completer<void>? _endSignal;

  void end() {
    _ended = true;
    _endSignal?.complete();
    _endSignal = null;
  }

  /// the response is done (also when it failed) and the handler ended.
  /// With a client that left, `done` can come before the handler ends.
  Future<void> _ready() {
    Future<void> done = _res.done.then((Object? _) {}, onError: (Object _) {});
    if (_ended) return done;
    Completer<void> signal = _endSignal ??= Completer<void>();
    return Future.wait(<Future<void>>[done, signal.future]);
  }

  void add(FutureOr<void> Function() item) {
    List<FutureOr<void> Function()>? work = _work;
    if (work != null) {
      work.add(item);
      return;
    }
    _work = <FutureOr<void> Function()>[item];
    // a response that is sent already completes this soon
    _flushed = _ready().then(flush);
  }

  Future<void> flush(Object? _) async {
    sent = true;
    List<FutureOr<void> Function()> work = _work!;
    for (FutureOr<void> Function() item in work) {
      await AfterResponse._call(item);
    }
    work.clear();
  }
}
