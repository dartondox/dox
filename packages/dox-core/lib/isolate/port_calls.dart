import 'dart:async';
import 'dart:isolate';

/// Sends requests to a port of another isolate and waits for the answers.
///
/// The other side gets `[replyPort, id, ...message]` and answers with
/// `[id, value]`, or `[id, null, false]` when it failed.
/// A request with no answer after [timeout] fails with a
/// [TimeoutException]. One timer checks all waiting requests, so there
/// is no timer per request. The timer only runs while a request waits.
class PortCalls {
  PortCalls(this.timeout);

  /// the most time to wait for an answer
  final Duration timeout;

  ReceivePort? _replies;
  int _nextId = 0;
  final Map<int, _Call> _waiting = <int, _Call>{};
  Timer? _timer;

  /// number of requests that wait for an answer
  int get waiting => _waiting.length;

  /// true while the timer that checks for timeouts runs
  bool get timerRuns => _timer != null;

  /// Sends [message] to [to] and gives the answer.
  Future<Object?> send(SendPort to, List<Object?> message) {
    ReceivePort replies = _replies ??= ReceivePort()..listen(_onReply);
    int id = _nextId++;
    _Call call = _Call(_nowMs() + timeout.inMilliseconds);
    _waiting[id] = call;
    // ponytail: a request can fail up to timeout / 5 late, fine for a
    // safety net that is not on the normal path
    _timer ??= Timer.periodic(timeout ~/ 5, _check);
    to.send(<Object?>[replies.sendPort, id, ...message]);
    return call.done.future;
  }

  /// Closes the reply port. Waiting requests fail.
  void close() {
    _replies?.close();
    _replies = null;
    _timer?.cancel();
    _timer = null;
    Map<int, _Call> left = Map<int, _Call>.of(_waiting);
    _waiting.clear();
    for (_Call call in left.values) {
      call.done.completeError(StateError('PortCalls closed'));
    }
  }

  /// Runs [run] with the message of a [send] and answers it. An error
  /// is not thrown here (it would stop the serving isolate). The caller
  /// gets a [StateError] with no details, so no data ends up in a log.
  static void answer(
    Object? message,
    FutureOr<Object?> Function(List<Object?> message) run,
  ) async {
    List<Object?> m = message as List<Object?>;
    SendPort reply = m[0] as SendPort;
    Object? id = m[1];
    try {
      reply.send(<Object?>[id, await run(m.sublist(2))]);
    } catch (_) {
      reply.send(<Object?>[id, null, false]);
    }
  }

  void _onReply(dynamic message) {
    List<Object?> m = message as List<Object?>;
    _Call? call = _waiting.remove(m[0] as int);
    if (_waiting.isEmpty) _stopTimer();
    if (call == null) return;
    if (m.length > 2) {
      call.done.completeError(StateError('The other isolate failed'));
    } else {
      call.done.complete(m[1]);
    }
  }

  void _check(Timer _) {
    int now = _nowMs();
    List<_Call> late = <_Call>[];
    _waiting.removeWhere((int id, _Call call) {
      if (call.deadline > now) return false;
      late.add(call);
      return true;
    });
    if (_waiting.isEmpty) _stopTimer();
    for (_Call call in late) {
      call.done.completeError(TimeoutException(null, timeout));
    }
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  static int _nowMs() => DateTime.now().millisecondsSinceEpoch;
}

class _Call {
  _Call(this.deadline);

  final int deadline;
  final Completer<Object?> done = Completer<Object?>();
}
