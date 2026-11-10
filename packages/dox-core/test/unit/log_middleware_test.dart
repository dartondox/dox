import 'dart:convert';

import 'package:dox_core/dox_core.dart';
import 'package:dox_core/utils/log_buffer.dart';
import 'package:test/test.dart';

/// a request with only what `LogMiddleware` reads
class FakeRequest implements IDoxRequest {
  @override
  String get method => 'GET';

  @override
  Uri get uri => Uri.parse('/a/b?x=1');

  @override
  Map<String, dynamic> get headers => <String, dynamic>{
    'authorization': 'secret-value',
    'accept': 'text/plain',
  };

  @override
  String ip() => '1.2.3.4';

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    'name': 'a',
    'password': 'hunter2',
  };

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

List<String> writes = <String>[];

List<String> get lines => writes
    .expand((String w) => w.split('\n'))
    .where((String l) => l.isNotEmpty)
    .toList();

void config({bool enabled = true, bool pretty = false, String level = 'info'}) {
  Dox().config = AppConfig(
    appKey: 'x',
    logger: LoggerConfig(
      enabled: enabled,
      prettyPrint: pretty,
      level: level,
      name: 'api',
    ),
  );
}

void main() {
  setUp(() {
    writes = <String>[];
    LogBuffer.writer = writes.add;
  });

  group('LogMiddleware |', () {
    test('json line has the datadog fields', () {
      config();
      LogMiddleware(withHeader: true).handle(FakeRequest());
      LogBuffer.flush();
      Map<String, dynamic> line = jsonDecode(lines.single);
      expect(line['status'], 'info');
      expect(line['message'], 'GET /a/b');
      expect(line['logger'], <String, dynamic>{'name': 'api'});
      expect(line['network']['client']['ip'], '1.2.3.4');
      expect(line['http'], <String, dynamic>{'method': 'GET', 'url': '/a/b'});
      expect(line['payload']['request']['name'], 'a');
      expect(line['payload']['request']['password'], '[REDACTED]');
      expect(line['payload']['headers']['authorization'], '[REDACTED]');
      expect(line['payload']['headers']['accept'], 'text/plain');
      expect(jsonEncode(line), isNot(contains('hunter2')));
    });

    test('headers only with withHeader', () {
      config();
      LogMiddleware().handle(FakeRequest());
      LogBuffer.flush();
      expect(
        jsonDecode(lines.single)['payload'].containsKey('headers'),
        isFalse,
      );
    });

    test('pretty mode gives colored text, not json', () {
      config(pretty: true);
      LogMiddleware().handle(FakeRequest());
      LogBuffer.flush();
      String line = lines.single;
      expect(line, startsWith('\x1B[36mGET /a/b => {'));
      expect(line, contains('[REDACTED]'));
      expect(line, isNot(contains('hunter2')));
      expect(line, isNot(contains('"status"')));
    });

    test('filter changes the line', () {
      config();
      LogMiddleware(
        filter: (Map<String, dynamic> l) {
          l.remove('payload');
          l['message'] = 'changed';
          l['env'] = 'test';
          return l;
        },
      ).handle(FakeRequest());
      LogBuffer.flush();
      Map<String, dynamic> line = jsonDecode(lines.single);
      expect(line['message'], 'changed');
      expect(line['env'], 'test');
      expect(line.containsKey('payload'), isFalse);
    });

    test('filter can return a map that can not change', () {
      config();
      Map<String, dynamic> out = Map<String, dynamic>.unmodifiable(
        <String, dynamic>{'status': 'error', 'message': 'fixed', 'a': 1},
      );
      LogMiddleware(filter: (Map<String, dynamic> l) => out)
          .handle(FakeRequest());
      LogBuffer.flush();
      Map<String, dynamic> line = jsonDecode(lines.single);
      expect(line['status'], 'error');
      expect(line['message'], 'fixed');
      expect(line['a'], 1);
      expect(out.containsKey('status'), isTrue);
    });

    test('enabled not set follows the logger config', () {
      config(enabled: false);
      LogMiddleware().handle(FakeRequest());
      LogBuffer.flush();
      expect(writes, isEmpty);

      config(level: 'warn');
      LogMiddleware().handle(FakeRequest());
      LogBuffer.flush();
      expect(writes, isEmpty);

      config();
      LogMiddleware().handle(FakeRequest());
      LogBuffer.flush();
      expect(lines.length, 1);
    });

    test('the logger config wins over enabled true', () {
      config(enabled: false);
      LogMiddleware(enabled: true).handle(FakeRequest());
      LogBuffer.flush();
      expect(writes, isEmpty);
    });

    test('enabled false turns only request logs off', () {
      config();
      LogMiddleware(enabled: false).handle(FakeRequest());
      Logger.info('other');
      LogBuffer.flush();
      expect(lines.length, 1);
      expect(jsonDecode(lines.single)['message'], 'other');
    });

    test('request lines keep their order with a danger line', () {
      config();
      LogMiddleware().handle(FakeRequest());
      Logger.danger('boom');
      expect(writes.length, 1);
      List<dynamic> messages = lines
          .map((String l) => jsonDecode(l)['message'])
          .toList();
      expect(messages, <String>['GET /a/b', 'boom']);
    });
  });
}
