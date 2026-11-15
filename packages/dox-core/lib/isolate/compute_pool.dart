import 'dart:async';
import 'dart:collection';
import 'dart:isolate';

import 'package:dox_core/interfaces/app_config.dart';

/// The worker isolates of `Dox().compute` and `Hash.makeAsync`.
///
/// One pool for the whole process. The isolate that opens [port] first
/// owns it: the main isolate in the web server, else the isolate that
/// uses it first (a CLI command, a test, a queue worker). Other server
/// isolates [connect] to it and send their tasks there.
///
/// The workers start on the first task and stay. Tasks beyond the pool
/// size wait in a FIFO queue. The pool never keeps the process alive:
/// only a caller that waits for a result does.
class ComputePool {
  ComputePool._();

  /// one per isolate
  static final ComputePool instance = ComputePool._();

  /// the number of workers. Read when the workers start, so set it
  /// before the first task. `Dox().initialize` sets it from
  /// `AppConfig.computeWorkers`.
  int size = AppConfig.defaultComputeWorkers;

  /// the port of the pool owner, null when this isolate owns the pool
  SendPort? _owner;

  /// owner side: tasks from other isolates and worker events come here
  RawReceivePort? _inbox;
  final List<_Worker> _workers = <_Worker>[];
  final Queue<_Job> _queue = Queue<_Job>();
  int _nextWorkerId = 0;

  /// The port other isolates send their tasks to. Opens the pool in this
  /// isolate. The workers do not start yet.
  SendPort get port => (_inbox ??= _openInbox()).sendPort;

  /// send the tasks of this isolate to the pool behind [owner] (a [port]
  /// of another isolate). null runs a pool in this isolate.
  void connect(SendPort? owner) {
    _owner = owner;
  }

  /// run [task] on a worker and give its result. An error of the task is
  /// thrown here, with the stack trace of the worker.
  Future<R> run<R>(FutureOr<R> Function() task) {
    _Call<R> call = _Call<R>();
    _Job job = _Job(task, call.port.sendPort);
    SendPort? owner = _owner;
    if (owner == null) {
      _inbox ??= _openInbox();
      _add(job);
      return call.done.future;
    }
    try {
      owner.send(job);
    } catch (error, stackTrace) {
      call.fail(_notSendable(error), stackTrace);
    }
    // ponytail: a task sent after the owner closed (during shutdown) is
    // lost and never ends. Add a timeout if this shows up in practice.
    return call.done.future;
  }

  /// Stop the workers. Running and waiting tasks fail with a
  /// [StateError]. A connected isolate only stops sending to the owner.
  /// A later [run] starts a new pool.
  void close() {
    _owner = null;
    StateError closed = StateError(
      'The compute pool was closed before the task was done. '
      'The server is stopping.',
    );
    for (_Worker worker in _workers) {
      worker.isolate?.kill(priority: Isolate.immediate);
      worker.job?.fail(closed);
    }
    while (_queue.isNotEmpty) {
      _queue.removeFirst().fail(closed);
    }
    _workers.clear();
    _inbox?.close();
    _inbox = null;
  }

  RawReceivePort _openInbox() {
    RawReceivePort inbox = RawReceivePort(_onMessage, 'dox compute pool');
    // the pool alone must not keep the isolate (and the process) alive
    inbox.keepIsolateAlive = false;
    return inbox;
  }

  void _onMessage(Object? message) {
    if (message is _Job) {
      _add(message);
    } else if (message is _Ready) {
      _Worker? worker = _find(message.id);
      worker?.port = message.port;
      _dispatch();
    } else if (message is _Idle) {
      _find(message.id)?.job = null;
      _dispatch();
    } else if (message is int) {
      _onExit(message);
    }
  }

  void _add(_Job job) {
    if (_workers.isEmpty) {
      if (size < 1) {
        job.fail(
          ArgumentError.value(size, 'computeWorkers', 'must be 1 or more'),
        );
        return;
      }
      for (int i = 0; i < size; i++) {
        unawaited(_spawn());
      }
    }
    _queue.add(job);
    _dispatch();
  }

  /// give waiting tasks to free workers, oldest first
  void _dispatch() {
    for (_Worker worker in _workers) {
      SendPort? port = worker.port;
      while (_queue.isNotEmpty && port != null && worker.job == null) {
        _Job job = _queue.removeFirst();
        try {
          port.send(job);
          worker.job = job;
        } catch (error, stackTrace) {
          job.fail(_notSendable(error), stackTrace);
        }
      }
    }
  }

  _Worker? _find(int id) {
    for (_Worker worker in _workers) {
      if (worker.id == id) return worker;
    }
    return null;
  }

  Future<void> _spawn() async {
    _Worker worker = _Worker(_nextWorkerId++);
    _workers.add(worker);
    SendPort inbox = port;
    try {
      // paused, so the exit listener is there before the task can run
      Isolate isolate = await Isolate.spawn(
        _ComputeWorker.main,
        _Start(worker.id, inbox),
        paused: true,
        debugName: 'dox compute ${worker.id}',
      );
      if (!_workers.contains(worker)) {
        // the pool was closed while the isolate started
        isolate.kill(priority: Isolate.immediate);
        return;
      }
      // the worker id comes back when the isolate ends
      isolate.addOnExitListener(inbox, response: worker.id);
      worker.isolate = isolate;
      isolate.resume(isolate.pauseCapability!);
    } catch (error, stackTrace) {
      // the isolate could not start: fail the tasks, a later run tries again
      _workers.remove(worker);
      if (_workers.every(_notStarted)) {
        while (_queue.isNotEmpty) {
          _queue.removeFirst().fail(error, stackTrace);
        }
      }
    }
  }

  static bool _notStarted(_Worker worker) => worker.isolate == null;

  void _onExit(int id) {
    _Worker? worker = _find(id);
    if (worker == null) return;
    _workers.remove(worker);
    worker.job?.fail(
      StateError(
        'The worker isolate of Dox().compute stopped before the task was '
        'done. Do not call Isolate.exit() in a task, and await every '
        'Future in it, so no error is left uncaught.',
      ),
    );
    // a new worker in its place
    unawaited(_spawn());
    _dispatch();
  }

  static ArgumentError _notSendable(Object error) {
    return ArgumentError(
      'The task of Dox().compute can not be sent to a worker isolate. It '
      'may only use values that can be sent between isolates (no open '
      'sockets, ports or database connections). $error',
    );
  }
}

/// a task and the port that gets its result
class _Job {
  _Job(this.task, this.reply);

  final FutureOr<Object?> Function() task;
  final SendPort reply;

  void fail(Object error, [StackTrace? stackTrace]) {
    reply.send(_Result.error(error, stackTrace ?? StackTrace.current));
  }
}

class _Worker {
  _Worker(this.id);

  final int id;
  Isolate? isolate;

  /// null until the worker is ready
  SendPort? port;

  /// the running task, null when the worker is free
  _Job? job;
}

class _Start {
  const _Start(this.id, this.pool);

  final int id;
  final SendPort pool;
}

class _Ready {
  const _Ready(this.id, this.port);

  final int id;
  final SendPort port;
}

class _Idle {
  const _Idle(this.id);

  final int id;
}

/// the result of one task: a value, or an error with its stack trace
class _Result {
  _Result.ok(this.value) : failed = false, stack = null;

  _Result.error(Object error, StackTrace stackTrace)
    : value = error,
      failed = true,
      stack = stackTrace.toString();

  final bool failed;
  final Object? value;

  /// as text: a [StackTrace] object can not always be sent
  final String? stack;
}

/// the caller side of one task
class _Call<R> {
  _Call() {
    port.handler = _onResult;
  }

  final RawReceivePort port = RawReceivePort();
  final Completer<R> done = Completer<R>();

  void fail(Object error, StackTrace stackTrace) {
    port.close();
    done.completeError(error, stackTrace);
  }

  void _onResult(Object? message) {
    port.close();
    _Result result = message as _Result;
    if (result.failed) {
      done.completeError(result.value!, StackTrace.fromString(result.stack!));
    } else {
      done.complete(result.value as R);
    }
  }
}

/// the loop of one worker isolate
class _ComputeWorker {
  _ComputeWorker(this.id, this.pool);

  final int id;
  final SendPort pool;

  static void main(_Start start) {
    _ComputeWorker worker = _ComputeWorker(start.id, start.pool);
    RawReceivePort jobs = RawReceivePort(worker.run, 'dox compute jobs');
    start.pool.send(_Ready(start.id, jobs.sendPort));
  }

  Future<void> run(Object? message) async {
    _Job job = message as _Job;
    try {
      Object? value = await job.task();
      _send(job.reply, _Result.ok(value));
    } catch (error, stackTrace) {
      _send(job.reply, _Result.error(error, stackTrace));
    }
    pool.send(_Idle(id));
  }

  /// send [result]. A value or an error that can not be sent becomes an
  /// error the caller can read.
  static void _send(SendPort reply, _Result result) {
    try {
      reply.send(result);
    } catch (error, stackTrace) {
      Object value = result.failed
          ? RemoteError('${result.value}', result.stack ?? '')
          : ArgumentError(
              'The result of Dox().compute can not be sent back from the '
              'worker isolate. Return plain data (numbers, strings, lists, '
              'maps). $error',
            );
      reply.send(_Result.error(value, stackTrace));
    }
  }
}
