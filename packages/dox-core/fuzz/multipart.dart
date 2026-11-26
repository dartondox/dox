import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:dox_core/http/request/form_data_visitor.dart';
import 'package:dox_core/http/request/form_input.dart';
import 'package:dox_core/http/request/http_request_body.dart';

import 'src/async_fuzz_target.dart';

/// A multipart body (`multipart/form-data`), read like `req.body`.
class MultipartTarget extends AsyncFuzzTarget {
  const MultipartTarget();

  static const String boundary = 'XBOUNDARY';

  @override
  String get name => 'multipart';

  @override
  List<Uint8List> get seeds => <Uint8List>[
    _body(<String>[
      'Content-Disposition: form-data; name="title"\r\n\r\nhello',
      'Content-Disposition: form-data; name="tags[]"\r\n\r\na',
      'Content-Disposition: form-data; name="tags[]"\r\n\r\nb',
    ]),
    _body(<String>[
      'Content-Disposition: form-data; name="file"; filename="a.txt"\r\n'
          'Content-Type: text/plain\r\n\r\nfile text',
      'Content-Disposition: form-data; name="user[name]"\r\n\r\nx',
    ]),
    _body(<String>[
      'Content-Disposition: form-data; name="q\\"uote"; filename=b.bin\r\n'
          'Content-Type: application/octet-stream\r\n\r\n\x00\x01\x02',
    ]),
  ];

  static Uint8List _body(List<String> parts) {
    StringBuffer out = StringBuffer();
    for (String part in parts) {
      out.write('--$boundary\r\n$part\r\n');
    }
    out.write('--$boundary--\r\n');
    return latin1.encode(out.toString());
  }

  /// the same steps as `HttpBody.read`
  @override
  Future<void> check(Uint8List input, Random random) async {
    FormDataVisitor visitor = FormDataVisitor(
      _Request(),
      HttpBody.limit(
        Stream<List<int>>.fromIterable(chunks(input, random)),
        1024 * 1024,
      ),
      boundary: boundary,
    );
    await visitor.process();
    const FormInput().nested(visitor.inputs, () => visitor.parts);
  }
}

/// The visitor reads the request only when it has no boundary, and uses
/// it as the key of its temp files.
class _Request implements HttpRequest {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> main(List<String> args) => const MultipartTarget().run(args);
