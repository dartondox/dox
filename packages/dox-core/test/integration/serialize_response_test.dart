import 'dart:convert';
import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:test/test.dart';

import '../serialize/serialize.dart';
import '../utils/start_http_server.dart';
import '../utils/test_app_key.dart';

AppConfig _config({required bool sdkEncoder}) {
  return AppConfig(
    appKey: testAppKey,
    // the OS picks a free port, so test files can run in parallel
    serverPort: 0,
    totalIsolate: 1,
    container: registerSerializeWriters,
    flags: CoreFlags(sdkJsonEncoder: sdkEncoder),
  );
}

void _routes() {
  Route.get('/plain', (DoxRequest req) {
    return ExtraUserData(
      loginCount: 1,
      lastSeen: DateTime.utc(2024, 2, 3),
      roles: <String>['admin'],
      level: Level.pro,
    );
  });
  Route.get('/plains', (DoxRequest req) {
    return const <Address>[Address(city: 'a'), Address(city: 'b')];
  });
  Route.get('/serializer', (DoxRequest req) {
    return PostSerializer(<Post>[
      Post('one', <Tag>[Tag('x')]),
    ]);
  });
}

Future<String> _get(String path) async {
  HttpClient client = HttpClient();
  try {
    HttpClientRequest req = await client.get(
      '127.0.0.1',
      Dox().server.httpServer.port,
      path,
    );
    HttpClientResponse res = await req.close();
    expect(res.statusCode, 200);
    expect(res.headers.contentType?.mimeType, 'application/json');
    return await utf8.decodeStream(res);
  } finally {
    client.close();
  }
}

void main() {
  setUp(_routes);

  tearDown(() async {
    await Dox().server.close();
  });

  for (bool sdk in <bool>[false, true]) {
    test('@Serialize() values as the response, sdkJsonEncoder: $sdk', () async {
      await startHttpServer(_config(sdkEncoder: sdk));
      expect(
        await _get('/plain'),
        '{"login_count":1,"seen":"2024-02-03T00:00:00.000Z",'
        '"roles":["admin"],"level":"pro","levels":[],'
        '"home":{"city":"Yangon","zip_code":null},"work":null,"others":[],'
        '"counts":{},"meta":{},"ratio":0.5,"account":null}',
      );
      expect(
        await _get('/plains'),
        '[{"city":"a","zip_code":null},{"city":"b","zip_code":null}]',
      );
      expect(
        await _get('/serializer'),
        '[{"title":"one","tags":["x"],"labels":[{"tag":"x"}]}]',
      );
    });
  }
}
