import 'dart:convert';

import 'package:dox_core/dox_core.dart';
import 'package:dox_core/utils/log_buffer.dart';
import 'package:test/test.dart';

/// what the buffer wrote, one entry per write
List<String> writes = <String>[];

/// every line that was written so far
List<String> get lines => writes
    .expand((String w) => w.split('\n'))
    .where((String l) => l.isNotEmpty)
    .toList();

void config({bool pretty = false, String level = 'info', String name = 'api'}) {
  Dox().config = AppConfig(
    appKey: 'x',
    logger: LoggerConfig(
      enabled: true,
      prettyPrint: pretty,
      level: level,
      name: name,
    ),
  );
}

void main() {
  setUp(() {
    writes = <String>[];
    LogBuffer.writer = writes.add;
  });

  tearDown(() {
    LogBuffer.flush();
  });

  group('Logger |', () {
    test('level hides lower lines', () {
      config(pretty: true, level: 'warn');
      Logger.info('info line');
      Logger.success('success line');
      Logger.warn('warn line');
      Logger.danger('danger line');
      expect(lines.length, 2);
      expect(lines[0], contains('warn line'));
      expect(lines[1], contains('danger line'));
    });

    test('disabled logger writes nothing', () {
      Dox().config = AppConfig(appKey: 'x');
      Logger.danger('no');
      LogBuffer.flush();
      expect(writes, isEmpty);
    });

    test('shouldLog', () {
      expect(Logger.shouldLog('info', 'info'), isTrue);
      expect(Logger.shouldLog('success', 'info'), isTrue);
      expect(Logger.shouldLog('info', 'debug'), isTrue);
      expect(Logger.shouldLog('info', 'ERROR'), isFalse);
      expect(Logger.shouldLog('danger', 'error'), isTrue);
      expect(Logger.shouldLog('warn', 'warning'), isTrue);
      // unknown setting: print everything
      expect(Logger.shouldLog('info', 'loud'), isTrue);
    });

    test('json line has the standard attributes', () {
      config();
      Logger.info('hello');
      LogBuffer.flush();
      Map<String, dynamic> line = jsonDecode(lines.single);
      expect(line['status'], 'info');
      expect(line['message'], 'hello');
      expect(line['logger'], <String, dynamic>{'name': 'api'});
      expect(DateTime.tryParse(line['timestamp']), isNotNull);
      expect(line.containsKey('payload'), isFalse);
      expect(line.containsKey('level'), isFalse);
    });

    test('a Map in data goes to the top level', () {
      config();
      Logger.info('hi', <String, dynamic>{
        'http': <String, dynamic>{'method': 'GET'},
        'user': 1,
      });
      LogBuffer.flush();
      Map<String, dynamic> line = jsonDecode(lines.single);
      expect(line['http'], <String, dynamic>{'method': 'GET'});
      expect(line['user'], 1);
      expect(line.containsKey('payload'), isFalse);
    });

    test('other data goes under payload', () {
      config();
      Logger.info('hi', 'text');
      Logger.info('hi', <int>[1, 2]);
      LogBuffer.flush();
      expect(jsonDecode(lines[0])['payload'], 'text');
      expect(jsonDecode(lines[1])['payload'], <int>[1, 2]);
    });

    test('empty name leaves out logger', () {
      config(name: '');
      Logger.info('hi');
      LogBuffer.flush();
      expect(jsonDecode(lines.single).containsKey('logger'), isFalse);
    });

    test('pretty mode gives colored text, not json', () {
      config(pretty: true);
      Logger.info('hello', <String, dynamic>{'a': 1});
      LogBuffer.flush();
      expect(lines.single, '\x1B[36mhello => {"a":1}\x1B[0m');
    });

    test('info waits in the buffer until flush', () {
      config();
      Logger.info('a');
      expect(writes, isEmpty);
      LogBuffer.flush();
      expect(writes.length, 1);
    });

    test('danger and warn are written right away, in order', () {
      config();
      Logger.info('one');
      Logger.success('two');
      expect(writes, isEmpty);
      Logger.danger('three');
      expect(writes.length, 1);
      expect(lines.map((String l) => jsonDecode(l)['message']), <String>[
        'one',
        'two',
        'three',
      ]);
      Logger.warn('four');
      expect(writes.length, 2);
      expect(jsonDecode(writes[1])['message'], 'four');
    });
  });
}
