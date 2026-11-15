import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:dox_core/http/http_cors_handler.dart';
import 'package:dox_http_native/dox_http_native.dart';
import 'package:test/test.dart';

import '../utils/test_app_key.dart';

/// request headers that count lookups
class _ReqHeaders implements HttpHeaders {
  _ReqHeaders(this.origin);

  final String? origin;
  int reads = 0;

  @override
  String? value(String name) {
    reads++;
    return name == 'origin' ? origin : null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Res implements HttpResponse {
  @override
  final NativeHeaders headers = NativeHeaders.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Req implements HttpRequest {
  _Req(this.headers);

  @override
  final _ReqHeaders headers;

  @override
  final _Res response = _Res();

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// the CORS headers set for a request from [origin], and the header reads
/// a record compares maps by identity, a list compares them deeply
List<Object> want(Map<String, List<String>> headers, int reads) {
  return <Object>[headers, reads];
}

List<Object> run(
  CORSConfig cors, {
  String? origin = 'https://b.com',
  bool? enabled,
}) {
  Dox().initialize(AppConfig(appKey: testAppKey, cors: cors));
  _Req req = _Req(_ReqHeaders(origin));
  httpCorsHandler(enabled, req);
  Map<String, List<String>> out = <String, List<String>>{};
  req.response.headers.forEach((String name, List<String> values) {
    out[name] = values;
  });
  return want(out, req.headers.reads);
}

void main() {
  test('the default config adds nothing and reads no header', () {
    expect(run(const CORSConfig()), want(<String, List<String>>{}, 0));
  });

  test('off adds nothing', () {
    expect(
      run(const CORSConfig(origin: '*'), enabled: false),
      want(<String, List<String>>{}, 0),
    );
  });

  test('one origin or * is sent without a header read', () {
    expect(
      run(const CORSConfig(origin: '*')),
      want(<String, List<String>>{
        'access-control-allow-origin': <String>['*'],
      }, 0),
    );
  });

  test('a list sends the request origin when it is in the list', () {
    CORSConfig cors = const CORSConfig(
      origin: <String>['https://a.com', 'https://b.com'],
    );
    expect(
      run(cors),
      want(<String, List<String>>{
        'vary': <String>['Origin'],
        'access-control-allow-origin': <String>['https://b.com'],
      }, 1),
    );
    expect(
      run(cors, origin: 'https://evil.com'),
      want(<String, List<String>>{
        'vary': <String>['Origin'],
      }, 1),
    );
  });

  test('all other values are sent as before', () {
    expect(
      run(
        const CORSConfig(
          methods: <String>['GET', 'POST'],
          headers: 'x-a',
          exposeHeaders: <String>['x-b'],
          credentials: true,
          maxAge: 60,
        ),
      ),
      want(<String, List<String>>{
        'access-control-allow-methods': <String>['GET,POST'],
        'access-control-allow-headers': <String>['x-a'],
        'access-control-expose-headers': <String>['x-b'],
        'access-control-allow-credentials': <String>['true'],
        'access-control-max-age': <String>['60'],
      }, 0),
    );
  });
}
