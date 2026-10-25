import 'dart:convert';

import 'package:matcher/expect.dart';

/// The answer to a [DoxTestClient] request.
///
/// The `expect...` methods fail the test when the answer is not right.
/// They return the response, so you can chain them:
/// ```
/// (await client.get('/api/ping')).expectStatus(200).expectBody('pong');
/// ```
class TestResponse {
  TestResponse(this.status, this.headers, this.bodyBytes);

  /// the http status code, eg. 200
  final int status;

  /// the headers, with lower case names. Many values are joined by `, `.
  final Map<String, String> headers;

  /// the raw body
  final List<int> bodyBytes;

  /// the body as text
  late final String body = utf8.decode(bodyBytes, allowMalformed: true);

  /// the body read as JSON
  late final dynamic json = jsonDecode(body);

  /// a header value, or null. The name can be in any case.
  String? header(String name) => headers[name.toLowerCase()];

  /// fail the test when the status is not [code]
  TestResponse expectStatus(int code) {
    expect(status, code, reason: 'Wrong status. The body is: $body');
    return this;
  }

  /// fail the test when the JSON body does not match [matcher]: a value
  /// (eg. a Map) or a matcher (eg. `containsPair('id', 1)`).
  TestResponse expectJson(Object? matcher) {
    expect(json, matcher);
    return this;
  }

  /// fail the test when the text body does not match [matcher]
  TestResponse expectBody(Object? matcher) {
    expect(body, matcher);
    return this;
  }

  /// fail the test when the header [name] does not match [matcher].
  /// Use `isNull` to check that a header is not there.
  TestResponse expectHeader(String name, Object? matcher) {
    expect(header(name), matcher, reason: 'Header $name');
    return this;
  }
}
