import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dox_http_native/dox_http_native.dart';
import 'package:test/test.dart';

void main() {
  test('request headers: one name is read from the raw bytes', () {
    NativeHeaders h = NativeHeaders.request(
      _raw(<List<String>>[
        <String>['x-test-long', 'no'],
        <String>['x-test', 'a'],
        <String>['accept', '*/*'],
        <String>['x-test', 'b'],
        <String>['content-type', 'application/json; charset=utf-8'],
      ]),
      http10: false,
    );
    expect(h['x-test'], <String>['a', 'b']);
    expect(h['X-Test-Long'], <String>['no']);
    expect(h['x'], isNull);
    expect(h.value('missing'), isNull);
    expect(h.contentType?.mimeType, 'application/json');
    expect(identical(h.contentType, h.contentType), isTrue);
    expect(h.persistentConnection, isTrue);
    List<String> names = <String>[];
    h.forEach((String name, List<String> values) => names.add(name));
    expect(names, <String>['x-test-long', 'x-test', 'accept', 'content-type']);
  });

  test('response content type is kept without a parse', () {
    NativeHeaders h = NativeHeaders.response(NativeHeaders.empty());
    h.contentType = ContentType.json;
    expect(h.value(HttpHeaders.contentTypeHeader), ContentType.json.toString());
    expect(identical(h.contentType, ContentType.json), isTrue);
    h.set(HttpHeaders.contentTypeHeader, 'text/html');
    expect(h.contentType?.mimeType, 'text/html');
  });

  test('defaults plus one content type stay shared until a change', () {
    NativeHeaders defaults = NativeHeaders.empty()
      ..set(HttpHeaders.contentTypeHeader, 'text/plain')
      ..set('x-a', '1');
    NativeHeaders h = NativeHeaders.response(defaults);
    h.contentType = ContentType.json;
    expect(h.isShared, isFalse);
    expect(identical(h.sharedType, ContentType.json), isTrue);
    expect(h.value(HttpHeaders.contentTypeHeader), ContentType.json.toString());
    h.set('x-b', '2');
    expect(h.sharedType, isNull);
    Map<String, List<String>> all = <String, List<String>>{};
    h.forEach((String name, List<String> values) => all[name] = values);
    expect(all, <String, List<String>>{
      'content-type': <String>[ContentType.json.toString()],
      'x-a': <String>['1'],
      'x-b': <String>['2'],
    });
    // the defaults did not change
    expect(defaults.value(HttpHeaders.contentTypeHeader), 'text/plain');
    expect(defaults['x-b'], isNull);
  });

  test('response header values with a line break are refused', () {
    NativeHeaders h = NativeHeaders.response(NativeHeaders.empty());
    for (String value in <String>[
      'a\nset-cookie: x=1',
      'a\r\nset-cookie: x=1',
      'a\u010Aset-cookie: x=1',
      'a\u0000',
    ]) {
      expect(() => h.set('x-id', value), throwsFormatException);
      expect(() => h.add('x-id', <String>['ok', value]), throwsFormatException);
    }
    for (String name in <String>['a b', 'a:b', 'a\nb', 'é']) {
      expect(() => h.set(name, 'v'), throwsFormatException);
    }
    h.set('x-id', 'a\tb ~!');
    expect(h.value('x-id'), 'a\tb ~!');
  });
}

/// the header block like Rust writes it
Uint8List _raw(List<List<String>> headers) {
  BytesBuilder b = BytesBuilder();
  for (List<String> h in headers) {
    List<int> name = latin1.encode(h[0]);
    List<int> value = latin1.encode(h[1]);
    b.add(<int>[name.length, 0, value.length, 0, ...name, ...value]);
  }
  return b.takeBytes();
}
