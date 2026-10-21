import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../constants/storage_constants.dart';
import '../../exceptions.dart';
import 's3_client.dart';

/// One S3 multipart upload: start, upload parts, then complete or abort.
class S3MultipartUpload {
  final S3Client client;
  final String key;
  final String uploadId;
  final List<String> _etags = <String>[];

  S3MultipartUpload._(this.client, this.key, this.uploadId);

  /// Start an upload. [headers] are the object headers (content type, ACL).
  static Future<S3MultipartUpload> start(
    S3Client client,
    String key,
    Map<String, String> headers,
  ) async {
    http.Response response = await client.send(
      'POST',
      client.objectUri(key, <String, String>{'uploads': ''}),
      headers: headers,
    );
    client.checkBodyError(response, key);
    String? uploadId = client.xml.first(client.text(response), 'UploadId');
    if (uploadId == null) {
      throw DriverException(key, 'S3 did not return an UploadId');
    }
    return S3MultipartUpload._(client, key, uploadId);
  }

  /// Upload the next part.
  Future<void> uploadPart(Uint8List bytes) async {
    int partNumber = _etags.length + 1;
    // ponytail: S3 caps uploads at 10,000 parts (~78 GiB with 8 MiB parts);
    // raise multipartPartSize for bigger files.
    if (partNumber > StorageConstants.maxMultipartParts) {
      throw DriverException(key, 'File is larger than 10,000 parts');
    }
    http.Response response = await client.send(
      'PUT',
      client.objectUri(key, <String, String>{
        'partNumber': '$partNumber',
        'uploadId': uploadId,
      }),
      body: bytes,
    );
    client.check(response, key);
    String? etag = response.headers['etag'];
    if (etag == null) {
      throw DriverException(key, 'S3 did not return an ETag for a part');
    }
    _etags.add(etag);
  }

  /// Finish the upload.
  Future<void> complete() async {
    StringBuffer body = StringBuffer('<CompleteMultipartUpload>');
    for (int i = 0; i < _etags.length; i++) {
      body.write(
        '<Part><PartNumber>${i + 1}</PartNumber>'
        '<ETag>${client.xml.escape(_etags[i])}</ETag></Part>',
      );
    }
    body.write('</CompleteMultipartUpload>');
    http.Response response = await client.send(
      'POST',
      client.objectUri(key, <String, String>{'uploadId': uploadId}),
      headers: <String, String>{'content-type': 'application/xml'},
      body: Uint8List.fromList(utf8.encode(body.toString())),
    );
    client.checkBodyError(response, key);
  }

  /// Cancel the upload so S3 drops the stored parts.
  Future<void> abort() async {
    await client.send(
      'DELETE',
      client.objectUri(key, <String, String>{'uploadId': uploadId}),
    );
  }
}
