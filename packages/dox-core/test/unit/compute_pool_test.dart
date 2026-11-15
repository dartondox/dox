import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:dox_core/dox_core.dart';
import 'package:dox_core/isolate/compute_pool.dart';
import 'package:test/test.dart';

int answer() => 21 * 2;

String workerName() => Isolate.current.debugName ?? '';

Never failInWorker() => throw StateError('boom');

Never exitWorker() => Isolate.exit();

Future<int> slow(int value) async {
  await Future<void>.delayed(const Duration(milliseconds: 30));
  return value;
}

Future<int> forever() => Completer<int>().future;

/// made at the top level: a closure made in `main` would also hold the
/// other variables of `main`, and a port can not be sent
Future<int> Function() slowTask(int value) =>
    () => slow(value);

Future<String> fromOtherIsolate(SendPort owner) {
  return Isolate.run(() {
    ComputePool.instance.connect(owner);
    return ComputePool.instance.run(workerName);
  });
}

void main() {
  ComputePool pool = ComputePool.instance;

  setUp(() {
    pool.close();
    pool.size = AppConfig.defaultComputeWorkers;
  });

  tearDown(pool.close);

  test('Dox().compute gives the result of a worker isolate', () async {
    expect(await Dox().compute(answer), 42);
    expect(await Dox().compute(() => 'a' * 3), 'aaa');
    expect(await Dox().compute(workerName), startsWith('dox compute'));
  });

  test('an error comes back with the stack trace of the worker', () async {
    Object? error;
    StackTrace? stack;
    try {
      await Dox().compute(failInWorker);
    } catch (e, s) {
      error = e;
      stack = s;
    }
    expect(error, isA<StateError>());
    expect((error as StateError).message, 'boom');
    expect(stack.toString(), contains('failInWorker'));
  });

  test('tasks beyond the pool size wait, first come first served', () async {
    pool.size = 1;
    List<int> order = <int>[];
    List<Future<void>> all = <Future<void>>[
      for (int i = 0; i < 4; i++) pool.run(slowTask(i)).then(order.add),
    ];
    await Future.wait(all);
    expect(order, <int>[0, 1, 2, 3]);
  });

  test('a worker that dies fails its task and is replaced', () async {
    pool.size = 1;
    await expectLater(
      pool.run(exitWorker),
      throwsA(
        isA<StateError>().having(
          (StateError e) => e.message,
          'message',
          contains('stopped before the task was done'),
        ),
      ),
    );
    expect(await pool.run(answer), 42);
  });

  test('close fails running and waiting tasks, a later run starts '
      'again', () async {
    pool.size = 1;
    Future<int> running = pool.run(forever);
    Future<int> waiting = pool.run(answer);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    pool.close();
    Matcher closed = throwsA(isA<StateError>());
    await expectLater(running, closed);
    await expectLater(waiting, closed);
    expect(await pool.run(answer), 42);
  });

  test('a task that can not be sent fails with a clear error', () async {
    ReceivePort open = ReceivePort();
    await expectLater(
      pool.run(() => open.hashCode),
      throwsA(isA<ArgumentError>()),
    );
    open.close();
  });

  test('a result that can not be sent back fails with an error', () async {
    await expectLater(pool.run(ReceivePort.new), throwsA(isA<ArgumentError>()));
  });

  test('computeWorkers below 1 fails the task', () async {
    pool.size = 0;
    await expectLater(pool.run(answer), throwsA(isA<ArgumentError>()));
  });

  test('another isolate sends its tasks to the shared pool', () async {
    String name = await fromOtherIsolate(pool.port);
    expect(name, startsWith('dox compute'));
  });

  test('Hash.makeAsync and verifyAsync run on the pool', () async {
    String hashed = await Hash.makeAsync('secret', rounds: 4);
    expect(await Hash.verifyAsync('secret', hashed), isTrue);
    expect(await Hash.verifyAsync('wrong', hashed), isFalse);
    pool.close();
    pool.size = 0;
    // no workers: the pool says so, so the hash did go through it
    await expectLater(Hash.makeAsync('secret'), throwsA(isA<ArgumentError>()));
    await expectLater(
      Hash.verifyAsync('secret', hashed),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('the pool does not keep a command process alive', () async {
    Directory dir = Directory.systemTemp.createTempSync('dox_compute');
    addTearDown(() => dir.deleteSync(recursive: true));
    File script = File('${dir.path}/main.dart')
      ..writeAsStringSync('''
import 'package:dox_core/dox_core.dart';

Future<void> main() async {
  String hashed = await Hash.makeAsync('secret', rounds: 4);
  print(await Hash.verifyAsync('secret', hashed));
}
''');
    Uri? packages = await Isolate.packageConfig;
    ProcessResult result = await Process.run(
      Platform.resolvedExecutable,
      <String>['--packages=${packages!.toFilePath()}', script.path],
    ).timeout(const Duration(seconds: 60));
    expect(result.exitCode, 0, reason: '${result.stderr}');
    expect((result.stdout as String).trim(), 'true');
  });
}
