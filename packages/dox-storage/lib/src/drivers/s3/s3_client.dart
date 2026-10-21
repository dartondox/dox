import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../clock.dart';
import '../../exceptions.dart';
import 's3_driver_config.dart';
import 's3_xml.dart';
import 'sigv4_signer.dart';

/// Builds, signs and sends S3 requests. Maps S3 errors to storage errors.
class S3Client {
  final S3DriverConfig config;
  final http.Client httpClient;
  final Clock clock;
  final SigV4Signer signer;
  final S3Xml xml;

  S3Client(
    this.config, {
    required this.httpClient,
    this.clock = const Clock(),
    this.xml = const S3Xml(),
  }) : signer = SigV4Signer(
          credentials: AwsCredentials(
            accessKeyId: config.accessKeyId,
            secretAccessKey: config.secretAccessKey,
            sessionToken: config.sessionToken,
          ),
          region: config.region,
        );

  /// Service endpoint without trailing slash.
  Uri get endpoint {
    String value =
        config.endpoint ?? 'https://s3.${config.region}.amazonaws.com';
    if (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    return Uri.parse(value);
  }

  /// URL of the bucket root, without query.
  String bucketUrl() {
    Uri base = endpoint;
    if (config.forcePathStyle) {
      return '${base.scheme}://${base.authority}/${config.bucket}';
    }
    return '${base.scheme}://${config.bucket}.${base.authority}';
  }

  /// URL of an object, with an optional query.
  Uri objectUri(String key, [Map<String, String>? query]) {
    String path = SigV4Signer.encode(key, encodeSlash: false);
    return _withQuery('${bucketUrl()}/$path', query);
  }

  /// URL of the bucket, with an optional query.
  Uri bucketUri([Map<String, String>? query]) {
    return _withQuery('${bucketUrl()}/', query);
  }

  Uri _withQuery(String url, Map<String, String>? query) {
    if (query == null || query.isEmpty) {
      return Uri.parse(url);
    }
    List<String> parts = <String>[];
    query.forEach((String name, String value) {
      parts.add('${SigV4Signer.encode(name)}=${SigV4Signer.encode(value)}');
    });
    return Uri.parse('$url?${parts.join('&')}');
  }

  /// Send a signed request with a buffered body.
  Future<http.Response> send(
    String method,
    Uri uri, {
    Map<String, String> headers = const <String, String>{},
    Uint8List? body,
  }) async {
    http.StreamedResponse response = await sendStreamed(
      method,
      uri,
      headers: headers,
      body: body,
    );
    return http.Response.fromStream(response);
  }

  /// Send a signed request and keep the response body as a stream.
  Future<http.StreamedResponse> sendStreamed(
    String method,
    Uri uri, {
    Map<String, String> headers = const <String, String>{},
    Uint8List? body,
  }) async {
    Uint8List payload = body ?? Uint8List(0);
    String hash = SigV4Signer.sha256Hex(payload);
    Map<String, String> unsigned = <String, String>{
      ...headers,
      'x-amz-content-sha256': hash,
    };
    Map<String, String> signed = signer.sign(
      method: method,
      uri: uri,
      now: clock.now(),
      headers: unsigned,
      payloadHash: hash,
    );
    // The HTTP client sets Host itself from the URL.
    signed.remove('host');
    http.Request request = http.Request(method, uri);
    request.headers.addAll(signed);
    request.bodyBytes = payload;
    return httpClient.send(request);
  }

  /// Throw unless the status is 2xx.
  void check(http.Response response, String key) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      fail(response.statusCode, text(response), key);
    }
  }

  /// Some S3 calls (copy, complete multipart) return 200 with an error body.
  void checkBodyError(http.Response response, String key) {
    check(response, key);
    String body = text(response);
    if (body.contains('<Error>')) {
      fail(500, body, key);
    }
  }

  /// Map an S3 error response to a storage exception.
  Never fail(int status, String body, String key) {
    String? code = xml.first(body, 'Code');
    String? message = xml.first(body, 'Message');
    String detail = 'S3 $status${code == null ? '' : ' $code'}'
        '${message == null ? '' : ': $message'}';
    if (code == 'NoSuchKey' || (status == 404 && code != 'NoSuchBucket')) {
      throw FileNotFoundException(key, cause: detail);
    }
    if (status == 403) {
      throw PermissionDeniedException(key, cause: detail);
    }
    throw DriverException(key, detail);
  }

  /// Response body as UTF-8. S3 sends XML without a charset, and
  /// `http.Response.body` would then decode it as Latin-1.
  String text(http.Response response) {
    return utf8.decode(response.bodyBytes, allowMalformed: true);
  }

  /// Read a streamed error body as text.
  Future<String> readBody(http.StreamedResponse response) async {
    return utf8.decode(await response.stream.toBytes(), allowMalformed: true);
  }
}
