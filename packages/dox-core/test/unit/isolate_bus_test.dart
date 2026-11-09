import 'dart:async';
import 'dart:isolate';

import 'package:dox_core/isolate/isolate_bus.dart';
import 'package:test/test.dart';

/// joins the hub [args.first] as isolate [args[1]], tells [args[2]] it is
/// ready, then sends back every message it gets on [args[2]]
Future<void> _member(List<Object> args) async {
  SendPort hub = args[0] as SendPort;
  int id = args[1] as int;
  SendPort out = args[2] as SendPort;
  IsolateBus bus = IsolateBus.instance..connect(hub, id);
  ReceivePort commands = ReceivePort();
  bus.messages.listen(out.send);
  commands.listen((dynamic command) {
    if (command == 'stop') {
      bus.close();
      commands.close();
    } else {
      bus.publish(command);
    }
  });
  out.send(commands.sendPort);
}

/// waits until [test] is true, for at most one second
Future<void> _until(bool Function() test) async {
  for (int i = 0; i < 100 && !test(); i++) {
    await Future<void>.delayed(Duration(milliseconds: 10));
  }
  expect(test(), isTrue);
}

void main() {
  tearDown(IsolateBus.instance.close);

  test('one isolate: publish sends nothing', () async {
    IsolateBus bus = IsolateBus.instance;
    List<Object?> got = <Object?>[];
    bus.messages.listen(got.add);
    bus.publish('hi');
    await Future<void>.delayed(Duration(milliseconds: 20));
    expect(got, isEmpty);
    expect(bus.size, 1);
  });

  test('a message reaches every other isolate, not the sender', () async {
    IsolateBus main = IsolateBus.instance;
    SendPort hub = main.port;
    List<Object?> gotMain = <Object?>[];
    main.messages.listen(gotMain.add);

    List<ReceivePort> outs = <ReceivePort>[];
    List<List<Object?>> got = <List<Object?>>[];
    List<SendPort> commands = <SendPort>[];
    for (int id = 2; id <= 3; id++) {
      ReceivePort out = ReceivePort();
      List<Object?> messages = <Object?>[];
      Completer<SendPort> ready = Completer<SendPort>();
      out.listen((dynamic m) {
        m is SendPort ? ready.complete(m) : messages.add(m);
      });
      await Isolate.spawn(_member, <Object>[hub, id, out.sendPort]);
      commands.add(await ready.future);
      outs.add(out);
      got.add(messages);
    }
    await _until(() => main.size == 3);

    commands[0].send(<Object>['from', 2]);
    main.publish('from main');
    await _until(() => gotMain.length == 1 && got[1].length == 2);
    expect(gotMain, <Object?>[
      <Object>['from', 2],
    ]);
    expect(got[0], <Object?>['from main']);
    // two senders: no order between them
    expect(
      got[1],
      unorderedEquals(<Object?>[
        <Object>['from', 2],
        'from main',
      ]),
    );

    // an isolate that leaves is not counted and gets nothing
    commands[0].send('stop');
    await _until(() => main.size == 2);
    main.drop(3); // like DoxIsolate after an isolate exits
    await _until(() => main.size == 1);
    main.publish('late');
    await Future<void>.delayed(Duration(milliseconds: 20));
    expect(got[0], <Object?>['from main']);
    expect(got[1].length, 2);
    commands[1].send('stop');
    for (ReceivePort out in outs) {
      out.close();
    }
  });
}
