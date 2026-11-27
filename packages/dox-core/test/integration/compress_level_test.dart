import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:test/test.dart';

import '../utils/start_http_server.dart';
import '../utils/test_app_key.dart';

AppConfig _config({int? level}) {
  return level == null
      ? AppConfig(
          appKey: testAppKey,
          serverPort: 0,
          totalIsolate: 1,
          compress: true,
        )
      : AppConfig(
          appKey: testAppKey,
          serverPort: 0,
          totalIsolate: 1,
          compress: true,
          compressLevel: level,
        );
}

/// the raw answer to a GET of [path] that accepts gzip
Future<List<int>> _raw(String path) async {
  Socket socket = await Socket.connect(
    '127.0.0.1',
    Dox().server.httpServer.port,
  );
  socket.add(
    utf8.encode(
      'GET $path HTTP/1.1\r\nHost: x\r\nAccept-Encoding: gzip\r\n'
      'Connection: close\r\n\r\n',
    ),
  );
  List<int> out = <int>[];
  await socket.listen(out.addAll).asFuture<void>();
  socket.destroy();
  return out;
}

/// the body of a raw answer
List<int> _body(List<int> answer) {
  String head = latin1.decode(answer);
  return answer.sublist(head.indexOf('\r\n\r\n') + 4);
}

Map<String, dynamic> _data() {
  return <String, dynamic>{
    'items': <Map<String, dynamic>>[
      for (int i = 0; i < 40; i++)
        <String, dynamic>{
          'id': i,
          'name': 'item $i',
          'tags': <String>['a', 'b'],
        },
    ],
  };
}

void main() {
  setUp(() {
    Route.get('/data', (DoxRequest req) => _data());
  });

  tearDown(() async {
    await Dox().server.close();
  });

  /// byte 8 of a gzip body (XFL) is 4 at level 1, 0 at levels 2 to 7 and
  /// 2 at levels 8 to 12
  for ((int?, int) want in <(int?, int)>[(null, 4), (1, 4), (6, 0), (12, 2)]) {
    test('compressLevel ${want.$1 ?? 'default (1)'}', () async {
      await startHttpServer(_config(level: want.$1));
      List<int> body = _body(await _raw('/data'));
      expect(body[8], want.$2);
      expect(utf8.decode(gzip.decode(body)), JSON.stringify(_data()));
    });
  }

  test('a level that is not 1 to 12 stops the start', () async {
    await expectLater(
      () => startHttpServer(_config(level: 13)),
      throwsA(isA<RangeError>()),
    );
    await expectLater(
      () => startHttpServer(_config(level: 0)),
      throwsA(isA<RangeError>()),
    );
    await startHttpServer(_config());
  });
}
