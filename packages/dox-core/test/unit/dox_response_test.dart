import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:dox_http_native/dox_http_native.dart';
import 'package:test/test.dart';

import '../utils/test_app_key.dart';

/// a response that is not native, that counts `close()` calls
class _Res implements HttpResponse {
  @override
  final NativeHeaders headers = NativeHeaders.empty();

  int closed = 0;

  @override
  Future<dynamic> close() async => closed++;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Req implements HttpRequest {
  @override
  final _Res response = _Res();

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  setUp(() => Dox().initialize(AppConfig(appKey: testAppKey)));

  test('headers: an empty map at first, the same map after', () {
    DoxResponse res = DoxResponse('x');
    expect(res.headers, isEmpty);
    expect(identical(res.headers, res.headers), isTrue);
    res.headers['x-a'] = '1';
    res.header('X-B', '2');
    res.header('x-a', '3');
    expect(res.headers, <String, dynamic>{'X-B': '2', 'x-a': '3'});
  });

  test('process sends headers, cookies and replaced values', () {
    _Req req = _Req();
    req.response.headers.set('x-r', 'old');
    DoxResponse(null)
        .header('x-a', '1')
        .header('x-r', 'new', replace: true)
        .cookie(DoxCookie('k', 'v'))
        .process(req);
    HttpHeaders h = req.response.headers;
    expect(h['x-a'], <String>['1']);
    expect(h['x-r'], <String>['new']);
    expect(h[HttpHeaders.setCookieHeader]?.single, startsWith('k='));
    // a null body closes the response: close() when it is not native
    expect(req.response.closed, 1);
  });

  test('a response with nothing set adds no header', () {
    _Req req = _Req();
    DoxResponse(null).process(req);
    int count = 0;
    req.response.headers.forEach((String _, List<String> _) => count++);
    expect(count, 0);
    expect(req.response.closed, 1);
  });
}
