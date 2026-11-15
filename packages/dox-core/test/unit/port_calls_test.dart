import 'dart:async';
import 'dart:isolate';

import 'package:dox_core/isolate/port_calls.dart';
import 'package:test/test.dart';

void main() {
  test('an answered call gives the value and stops the timer', () async {
    ReceivePort server = ReceivePort();
    server.listen((dynamic m) {
      PortCalls.answer(m, (List<Object?> args) => (args[0] as int) * 2);
    });
    PortCalls calls = PortCalls(const Duration(seconds: 5));
    expect(await calls.send(server.sendPort, <Object?>[21]), 42);
    expect(calls.waiting, 0);
    expect(calls.timerRuns, isFalse);
    calls.close();
    server.close();
  });

  test('a failed call is an error with no details', () async {
    ReceivePort server = ReceivePort();
    server.listen((dynamic m) {
      PortCalls.answer(m, (List<Object?> args) => throw StateError('secret'));
    });
    PortCalls calls = PortCalls(const Duration(seconds: 5));
    Object? error;
    try {
      await calls.send(server.sendPort, <Object?>[1]);
    } on StateError catch (e) {
      error = e;
    }
    expect(error.toString(), isNot(contains('secret')));
    calls.close();
    server.close();
  });

  test('one shared timer fails all calls with no answer', () async {
    // a port that never answers
    ReceivePort silent = ReceivePort();
    PortCalls calls = PortCalls(const Duration(milliseconds: 100));
    List<Future<Object?>> pending = <Future<Object?>>[
      for (int i = 0; i < 3; i++) calls.send(silent.sendPort, <Object?>[i]),
    ];
    expect(calls.waiting, 3);
    expect(calls.timerRuns, isTrue);
    for (Future<Object?> call in pending) {
      await expectLater(call, throwsA(isA<TimeoutException>()));
    }
    expect(calls.waiting, 0);
    expect(calls.timerRuns, isFalse);
    calls.close();
    silent.close();
  });

  test('a send that throws leaves nothing waiting and no timer', () {
    ReceivePort server = ReceivePort();
    PortCalls calls = PortCalls(const Duration(seconds: 5));
    // a ReceivePort can not be sent through a port
    expect(
      () => calls.send(server.sendPort, <Object?>[ReceivePort()]),
      throwsA(anything),
    );
    expect(calls.waiting, 0);
    expect(calls.timerRuns, isFalse);
    calls.close();
    server.close();
  });
}
