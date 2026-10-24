import 'dart:convert';
import 'dart:io';

import 'package:dox_storage/dox_storage.dart';
import 'package:test/test.dart';

Map<String, dynamic> _vectors() {
  String text = File('test/fixtures/sigv4_vectors.json').readAsStringSync();
  return jsonDecode(text) as Map<String, dynamic>;
}

SigV4Signer _signer(Map<String, dynamic> vector) {
  return SigV4Signer(
    credentials: AwsCredentials(
      accessKeyId: vector['accessKeyId'] as String,
      secretAccessKey: vector['secretAccessKey'] as String,
    ),
    region: vector['region'] as String,
    service: vector['service'] as String,
  );
}

void main() {
  Map<String, dynamic> vectors = _vectors();

  group('SigV4 header signing (AWS vectors)', () {
    for (Object? raw in vectors['header'] as List<dynamic>) {
      Map<String, dynamic> vector = raw as Map<String, dynamic>;
      test(vector['name'] as String, () {
        Map<String, String> headers = <String, String>{};
        (vector['headers'] as Map<String, dynamic>).forEach((
          String name,
          dynamic value,
        ) {
          headers[name] = value as String;
        });
        Map<String, String> signed = _signer(vector).sign(
          method: vector['method'] as String,
          uri: Uri.parse(vector['url'] as String),
          now: DateTime.parse(vector['date'] as String),
          headers: headers,
          payloadHash: vector['payloadHash'] as String,
        );
        expect(signed['authorization'], vector['authorization']);
      });
    }
  });

  group('SigV4 presigned URL (AWS vectors)', () {
    for (Object? raw in vectors['presign'] as List<dynamic>) {
      Map<String, dynamic> vector = raw as Map<String, dynamic>;
      test(vector['name'] as String, () {
        Uri url = _signer(vector).presign(
          method: vector['method'] as String,
          uri: Uri.parse(vector['url'] as String),
          now: DateTime.parse(vector['date'] as String),
          expiresIn: Duration(seconds: vector['expiresIn'] as int),
        );
        expect(url.queryParameters['X-Amz-Signature'], vector['signature']);
        expect(url.queryParameters['X-Amz-SignedHeaders'], 'host');
        expect(url.path, '/test.txt');
      });
    }
  });

  group('SigV4Signer.encode', () {
    test('keeps unreserved characters', () {
      expect(SigV4Signer.encode('aZ09-_.~'), 'aZ09-_.~');
    });

    test('encodes spaces, slashes and unicode', () {
      expect(SigV4Signer.encode('a b/c'), 'a%20b%2Fc');
      expect(SigV4Signer.encode('a/b', encodeSlash: false), 'a/b');
      expect(SigV4Signer.encode('é'), '%C3%A9');
    });
  });

  test('adds the session token when present', () {
    SigV4Signer signer = const SigV4Signer(
      credentials: AwsCredentials(
        accessKeyId: 'AK',
        secretAccessKey: 'SK',
        sessionToken: 'TOKEN',
      ),
      region: 'us-east-1',
    );
    Map<String, String> signed = signer.sign(
      method: 'GET',
      uri: Uri.parse('http://localhost:9000/bucket/key'),
      now: DateTime.utc(2024),
    );
    expect(signed['x-amz-security-token'], 'TOKEN');
    expect(signed['host'], 'localhost:9000');
    expect(signed['authorization'], contains('x-amz-security-token'));
  });

  test('the cached signing key is per secret and per date', () {
    String sign(String secret, DateTime now) {
      SigV4Signer signer = SigV4Signer(
        credentials: AwsCredentials(accessKeyId: 'AK', secretAccessKey: secret),
        region: 'us-east-1',
      );
      return signer.sign(
        method: 'GET',
        uri: Uri.parse('http://localhost:9000/bucket/key'),
        now: now,
      )['authorization']!;
    }

    DateTime day1 = DateTime.utc(2024, 1, 1, 10);
    String first = sign('SK1', day1);
    expect(sign('SK1', day1), first);
    expect(sign('SK2', day1), isNot(first));
    expect(sign('SK1', day1), first);
    String day2 = sign('SK1', DateTime.utc(2024, 1, 2, 10));
    expect(day2, isNot(first));
    expect(day2, contains('/20240102/'));
  });
}
