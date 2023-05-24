import 'dart:io';

import 'package:dox_core/request/request_file.dart';
import 'package:mime/mime.dart';
import 'package:string_scanner/string_scanner.dart';

class FormDataVisitor {
  final HttpRequest request;
  final token = RegExp(r'[^()<>@,;:"\\/[\]?={} \t\x00-\x1F\x7F]+');
  final whitespace = RegExp(r'(?:(?:\r\n)?[ \t]+)*');
  final quotedString = RegExp(r'"(?:[^"\x00-\x1F\x7F]|\\.)*"');
  final quotedPair = RegExp(r'\\(.)');

  final Map<String, dynamic> inputs = {};

  FormDataVisitor(this.request);

  Future process() async {
    var transformer = MimeMultipartTransformer(
        request.headers.contentType!.parameters['boundary']!);

    var formData =
        await request.cast<List<int>>().transform(transformer).toList();

    for (MimeMultipart formItem in formData) {
      String partHeaders = formItem.headers['content-disposition']!;
      String? contentType = formItem.headers['content-type'];

      Map<String, String> data = _parseFormDataContentDisposition(partHeaders);

      String? inputName = data['name'];
      if (inputName != null) {
        if (data['filename'] == null || data['filename']!.isEmpty) {
          var value = String.fromCharCodes(await formItem.first);
          inputs[inputName] = value;
        } else {
          var file = RequestFile(
            filename: data['filename'].toString(),
            filetype: contentType.toString(),
            stream: formItem,
          );
          inputs[inputName] = file;
        }
      }
    }
  }

  Map<String, String> _parseFormDataContentDisposition(String header) {
    final scanner = StringScanner(header);
    scanner
      ..scan(whitespace)
      ..expect(token);

    final params = <String, String>{};

    while (scanner.scan(';')) {
      scanner
        ..scan(whitespace)
        ..scan(token);
      final key = scanner.lastMatch![0]!;
      scanner.expect('=');

      String value;
      if (scanner.scan(token)) {
        value = scanner.lastMatch![0]!;
      } else {
        scanner.expect(quotedString, name: 'quoted string');
        final string = scanner.lastMatch![0]!;

        value = string
            .substring(1, string.length - 1)
            .replaceAllMapped(quotedPair, (match) => match[1]!);
      }

      scanner.scan(whitespace);
      params[key] = value;
    }

    scanner.expectDone();
    return params;
  }
}
