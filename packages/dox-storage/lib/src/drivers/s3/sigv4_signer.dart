import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../constants/storage_constants.dart';

/// AWS access keys.
class AwsCredentials {
  final String accessKeyId;
  final String secretAccessKey;

  /// Only for temporary credentials (STS).
  final String? sessionToken;

  const AwsCredentials({
    required this.accessKeyId,
    required this.secretAccessKey,
    this.sessionToken,
  });
}

/// AWS Signature Version 4 for S3.
///
/// [sign] adds an `Authorization` header. [presign] returns a URL with the
/// signature in the query string. The URI path must already be
/// percent-encoded (S3 style: each key segment encoded once).
class SigV4Signer {
  final AwsCredentials credentials;
  final String region;
  final String service;

  const SigV4Signer({
    required this.credentials,
    required this.region,
    this.service = 's3',
  });

  /// Return [headers] plus `host`, `x-amz-date`, the session token (if any)
  /// and `authorization`. All names are lowercase.
  Map<String, String> sign({
    required String method,
    required Uri uri,
    required DateTime now,
    Map<String, String> headers = const <String, String>{},
    String payloadHash = StorageConstants.emptyPayloadHash,
  }) {
    String amzDate = _amzDate(now);
    Map<String, String> all = <String, String>{};
    headers.forEach((String name, String value) {
      all[name.toLowerCase()] = value;
    });
    all['host'] ??= _host(uri);
    all['x-amz-date'] = amzDate;
    String? token = credentials.sessionToken;
    if (token != null) {
      all['x-amz-security-token'] = token;
    }

    List<String> names = all.keys.toList()..sort();
    String signedHeaders = names.join(';');
    String request = _canonicalRequest(
      method,
      uri,
      _canonicalQuery(_queryPairs(uri)),
      names,
      all,
      payloadHash,
    );
    String scope = _scope(now);
    String signature = _signature(now, _stringToSign(amzDate, scope, request));
    all['authorization'] = '${StorageConstants.sigV4Algorithm} '
        'Credential=${credentials.accessKeyId}/$scope, '
        'SignedHeaders=$signedHeaders, Signature=$signature';
    return all;
  }

  /// Return [uri] with presigned query parameters.
  /// Extra [headers] (like `content-type`) become signed headers, so the
  /// client must send them with the same value.
  Uri presign({
    required String method,
    required Uri uri,
    required DateTime now,
    required Duration expiresIn,
    Map<String, String> headers = const <String, String>{},
  }) {
    String amzDate = _amzDate(now);
    Map<String, String> all = <String, String>{'host': _host(uri)};
    headers.forEach((String name, String value) {
      all[name.toLowerCase()] = value;
    });
    List<String> names = all.keys.toList()..sort();
    String signedHeaders = names.join(';');
    String scope = _scope(now);

    List<List<String>> query = _queryPairs(uri);
    query.add(<String>['X-Amz-Algorithm', StorageConstants.sigV4Algorithm]);
    query.add(<String>[
      'X-Amz-Credential',
      '${credentials.accessKeyId}/$scope',
    ]);
    query.add(<String>['X-Amz-Date', amzDate]);
    query.add(<String>['X-Amz-Expires', '${expiresIn.inSeconds}']);
    String? token = credentials.sessionToken;
    if (token != null) {
      query.add(<String>['X-Amz-Security-Token', token]);
    }
    query.add(<String>['X-Amz-SignedHeaders', signedHeaders]);

    String canonicalQuery = _canonicalQuery(query);
    String request = _canonicalRequest(
      method,
      uri,
      canonicalQuery,
      names,
      all,
      StorageConstants.unsignedPayload,
    );
    String signature = _signature(
      now,
      _stringToSign(amzDate, scope, request),
    );
    String base = '${uri.scheme}://${uri.authority}${uri.path}';
    return Uri.parse('$base?$canonicalQuery&X-Amz-Signature=$signature');
  }

  /// URI-encode the AWS way: keep `A-Z a-z 0-9 - _ . ~`, encode the rest
  /// as `%XX` (uppercase). With [encodeSlash] false, `/` is kept.
  static String encode(String value, {bool encodeSlash = true}) {
    StringBuffer out = StringBuffer();
    for (int byte in utf8.encode(value)) {
      bool unreserved = (byte >= 0x41 && byte <= 0x5A) ||
          (byte >= 0x61 && byte <= 0x7A) ||
          (byte >= 0x30 && byte <= 0x39) ||
          byte == 0x2D ||
          byte == 0x5F ||
          byte == 0x2E ||
          byte == 0x7E ||
          (byte == 0x2F && !encodeSlash);
      if (unreserved) {
        out.writeCharCode(byte);
      } else {
        out.write('%${byte.toRadixString(16).toUpperCase().padLeft(2, '0')}');
      }
    }
    return out.toString();
  }

  /// Lowercase hex SHA-256 of [bytes].
  static String sha256Hex(List<int> bytes) {
    return sha256.convert(bytes).toString();
  }

  String _canonicalRequest(
    String method,
    Uri uri,
    String canonicalQuery,
    List<String> names,
    Map<String, String> headers,
    String payloadHash,
  ) {
    StringBuffer canonicalHeaders = StringBuffer();
    for (String name in names) {
      canonicalHeaders.write('$name:${_trim(headers[name]!)}\n');
    }
    String path = uri.path.isEmpty ? '/' : uri.path;
    return <String>[
      method.toUpperCase(),
      path,
      canonicalQuery,
      canonicalHeaders.toString(),
      names.join(';'),
      payloadHash,
    ].join('\n');
  }

  /// Decoded query pairs, in the order they appear.
  List<List<String>> _queryPairs(Uri uri) {
    List<List<String>> pairs = <List<String>>[];
    if (uri.query.isEmpty) {
      return pairs;
    }
    for (String part in uri.query.split('&')) {
      if (part.isEmpty) {
        continue;
      }
      int equals = part.indexOf('=');
      String name = equals == -1 ? part : part.substring(0, equals);
      String value = equals == -1 ? '' : part.substring(equals + 1);
      pairs
          .add(<String>[Uri.decodeComponent(name), Uri.decodeComponent(value)]);
    }
    return pairs;
  }

  String _canonicalQuery(List<List<String>> pairs) {
    List<String> encoded = <String>[];
    for (List<String> pair in pairs) {
      encoded.add('${encode(pair[0])}=${encode(pair[1])}');
    }
    encoded.sort();
    return encoded.join('&');
  }

  String _stringToSign(String amzDate, String scope, String request) {
    return <String>[
      StorageConstants.sigV4Algorithm,
      amzDate,
      scope,
      sha256Hex(utf8.encode(request)),
    ].join('\n');
  }

  String _signature(DateTime now, String stringToSign) {
    List<int> key = _hmac(
      utf8.encode('AWS4${credentials.secretAccessKey}'),
      _date(now),
    );
    key = _hmac(key, region);
    key = _hmac(key, service);
    key = _hmac(key, 'aws4_request');
    return Hmac(sha256, key).convert(utf8.encode(stringToSign)).toString();
  }

  List<int> _hmac(List<int> key, String data) {
    return Hmac(sha256, key).convert(utf8.encode(data)).bytes;
  }

  String _scope(DateTime now) {
    return '${_date(now)}/$region/$service/aws4_request';
  }

  String _host(Uri uri) {
    if (uri.hasPort &&
        !((uri.scheme == 'https' && uri.port == 443) ||
            (uri.scheme == 'http' && uri.port == 80))) {
      return '${uri.host}:${uri.port}';
    }
    return uri.host;
  }

  /// Trim and collapse inner spaces, as SigV4 asks.
  String _trim(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  String _date(DateTime now) {
    DateTime utc = now.toUtc();
    return '${utc.year.toString().padLeft(4, '0')}'
        '${_two(utc.month)}${_two(utc.day)}';
  }

  String _amzDate(DateTime now) {
    DateTime utc = now.toUtc();
    return '${_date(utc)}T${_two(utc.hour)}${_two(utc.minute)}'
        '${_two(utc.second)}Z';
  }

  String _two(int value) {
    return value.toString().padLeft(2, '0');
  }
}
