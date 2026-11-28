import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

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
  Encoding encoding = utf8;

  /// the bytes of the body
  List<int>? sent;

  @override
  void add(List<int> data) => sent = data;

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

  group('contentBytes', () {
    test('getContent gives the text, decoded one time', () {
      DoxResponse res = DoxResponse(null)
          .contentBytes(utf8.encode('caf\u00E9'));
      expect(res.getContent(), 'caf\u00E9');
      expect(identical(res.getContent(), res.getContent()), isTrue);
    });

    test('getContentBytes: the bytes, a String encoded, else null', () {
      Uint8List bytes = utf8.encode('x\u2014');
      expect(
        identical(
          DoxResponse(null).contentBytes(bytes).getContentBytes(),
          bytes,
        ),
        isTrue,
      );
      expect(
        DoxResponse('caf\u00E9').getContentBytes(),
        utf8.encode('caf\u00E9'),
      );
      expect(DoxResponse('abc').getContentBytes(), utf8.encode('abc'));
      expect(DoxResponse(<String, int>{'a': 1}).getContentBytes(), isNull);
      expect(DoxResponse(null).getContentBytes(), isNull);
    });

    test('htmlStrings: sent as text/html, like a String body', () {
      Dox().initialize(
        AppConfig(appKey: testAppKey, flags: CoreFlags(htmlStrings: true)),
      );
      for (DoxResponse res in <DoxResponse>[
        DoxResponse('<p>a</p>'),
        DoxResponse(null).contentBytes(utf8.encode('<p>a</p>')),
      ]) {
        _Req req = _Req();
        req.response.headers.set(
          HttpHeaders.contentTypeHeader,
          'text/plain; charset=utf-8',
        );
        res.process(req);
        expect(
          req.response.headers.value(HttpHeaders.contentTypeHeader),
          startsWith('text/html'),
        );
      }
    });

    test('a charset that is not UTF-8 encodes the text, like a String', () {
      for (DoxResponse res in <DoxResponse>[
        DoxResponse('caf\u00E9'),
        DoxResponse(null).contentBytes(utf8.encode('caf\u00E9')),
      ]) {
        _Req req = _Req();
        req.response.encoding = latin1;
        res.process(req);
        expect(req.response.sent, latin1.encode('caf\u00E9'));
      }
    });

    test('content() after contentBytes() drops the bytes', () {
      DoxResponse res = DoxResponse(null)
          .contentBytes(utf8.encode('old'))
          .content('new');
      expect(res.getContent(), 'new');
      expect(res.getContentBytes(), utf8.encode('new'));
    });
  });
}
