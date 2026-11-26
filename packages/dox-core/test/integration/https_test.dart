import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:dox_core/http/request/trusted_proxy.dart';
import 'package:dox_core/isolate/dox_isolate.dart';
import 'package:dox_core/testing.dart';
import 'package:http2/http2.dart';
import 'package:test/test.dart';

import '../utils/free_port.dart';
import '../utils/test_app_key.dart';

/// Time for one request. The full test run is busy, so it is generous.
const Duration _wait = Duration(seconds: 20);

/// Makes a self-signed certificate for `localhost` and `127.0.0.1` with
/// the name `dox test <n>`: `cert<n>.pem` and `key<n>.pem` in [dir]. Short
/// lived (macOS trusts no server certificate of more than 825 days).
/// Gives null, or why `openssl` could not make it.
String? makeCertificate(Directory dir, int n) {
  try {
    ProcessResult made = Process.runSync('openssl', <String>[
      'req',
      '-x509',
      '-nodes',
      '-days',
      '2',
      '-newkey',
      'ec',
      '-pkeyopt',
      'ec_paramgen_curve:prime256v1',
      '-keyout',
      '${dir.path}/key$n.pem',
      '-out',
      '${dir.path}/cert$n.pem',
      '-subj',
      '/CN=dox test $n',
      '-addext',
      'subjectAltName=DNS:localhost,IP:127.0.0.1',
      '-addext',
      'basicConstraints=critical,CA:FALSE',
    ]);
    return made.exitCode == 0 ? null : '${made.stderr}';
  } on ProcessException catch (error) {
    return error.message;
  }
}

/// The certificates are self-signed, so the check of the system fails.
/// The tests read the name of the certificate where it matters.
bool trusted(X509Certificate cert) => cert.subject.contains('dox test');

bool trustedFor(X509Certificate cert, String host, int port) => trusted(cert);

// The route handlers are top-level functions: with more than one isolate
// they go to the other isolates, and a closure of `main` can not.
String info(DoxRequest req) {
  return '${req.scheme()} ${req.protocolVersion} ${req.fullUrl()}';
}

String putSession(DoxRequest req) {
  req.session.put('name', 'dox');
  return req.scheme();
}

/// `/slow` tells [slowEntered] that it runs, then waits for [slowGate]
Completer<void> slowEntered = Completer<void>();
Completer<void> slowGate = Completer<void>();

Future<String> slow(DoxRequest req) async {
  slowEntered.complete();
  await slowGate.future;
  // the first read of the scheme of this request
  req.session.put('name', 'dox');
  return '${req.scheme()} ${req.fullUrl()}';
}

String isolateId(DoxRequest req) => '${Dox().isolateId}';

String signed(DoxRequest req) => 'signed';

void main() {
  Directory made = Directory.systemTemp.createTempSync('dox_core_https_certs_');
  String? problem = makeCertificate(made, 1) ?? makeCertificate(made, 2);

  tearDownAll(() => made.deleteSync(recursive: true));

  // a CI runner must not pass with the group skipped
  if (problem != null && Platform.environment['CI'] != null) {
    test('openssl makes the test certificate', () {
      fail('openssl can not make the test certificate: $problem');
    });
  }

  group(
    'https',
    // the tests need openssl 1.1.1 or newer (`-addext`). CI has it.
    skip: problem == null
        ? null
        : 'openssl can not make the test certificate: $problem',
    () {
      late Directory dir;
      late TlsOptions tls;
      late HttpClient client;
      bool started = false;

      setUpAll(() {
        Route.get('/info', info);
        Route.get('/session', <dynamic>[
          const SecurityHeaders(),
          const SessionMiddleware(),
          putSession,
        ]);
        // no SecurityHeaders: it reads the scheme before the handler
        Route.get('/slow', <dynamic>[const SessionMiddleware(), slow]);
        Route.get('/isolate', isolateId);
        Route.get('/signed', <dynamic>[
          const ValidateSignature(),
          signed,
        ]).name('https.signed');
      });

      setUp(() async {
        // copies, so the reload tests can change them
        dir = await Directory.systemTemp.createTemp('dox_core_https_');
        await File('${made.path}/cert1.pem').copy('${dir.path}/cert.pem');
        await File('${made.path}/key1.pem').copy('${dir.path}/key.pem');
        tls = TlsOptions(
          certificatePath: '${dir.path}/cert.pem',
          keyPath: '${dir.path}/key.pem',
        );
        client = HttpClient()..badCertificateCallback = trustedFor;
      });

      tearDown(() async {
        client.close(force: true);
        DoxIsolate().killAll();
        if (started) await Dox().server.close(force: true);
        started = false;
        await dir.delete(recursive: true);
      });

      AppConfig config({
        bool http2 = false,
        TlsOptions? tls,
        int port = 0,
        int totalIsolate = 1,
        List<String> trustedProxies = const <String>[],
      }) {
        return AppConfig(
          appKey: testAppKey,
          serverPort: port,
          totalIsolate: totalIsolate,
          host: '127.0.0.1',
          http2: http2,
          tls: tls,
          trustedProxies: trustedProxies,
        );
      }

      Future<void> start(AppConfig config) async {
        Dox().initialize(config);
        // `Dox` keeps the count of the first start of this isolate
        Dox().totalIsolate(config.totalIsolate);
        await Dox().startServer();
        started = true;
      }

      Future<HttpClientResponse> get(
        String scheme,
        String path, {
        String? forwardedProto,
      }) async {
        int port = Dox().server.httpServer.port;
        HttpClientRequest req = await client
            .getUrl(Uri.parse('$scheme://localhost:$port$path'))
            .timeout(_wait);
        if (forwardedProto != null) {
          req.headers.set('x-forwarded-proto', forwardedProto);
        }
        return req.close().timeout(_wait);
      }

      Future<String> body(HttpClientResponse res) {
        return utf8.decodeStream(res).timeout(_wait);
      }

      Future<SecureSocket> open(List<String> alpn) => SecureSocket.connect(
        'localhost',
        Dox().server.httpServer.port,
        onBadCertificate: trusted,
        supportedProtocols: alpn,
      ).timeout(_wait);

      /// One GET on a new connection. Gives the name of the certificate
      /// and the body.
      Future<(String, String)> fresh(String path) async {
        SecureSocket socket = await open(<String>['http/1.1']);
        String subject = socket.peerCertificate!.subject;
        socket.write(
          'GET $path HTTP/1.1\r\nHost: a\r\nConnection: close\r\n\r\n',
        );
        String answer = await utf8.decodeStream(socket).timeout(_wait);
        socket.destroy();
        return (subject, answer.split('\r\n\r\n').last);
      }

      test('reloadCertificate before the start throws a StateError', () async {
        await expectLater(Dox().server.reloadCertificate(), throwsStateError);
      });

      test(
        'tls on: HTTPS over HTTP/1.1, https scheme, Secure cookie',
        () async {
          await start(config(tls: tls));
          int port = Dox().server.httpServer.port;
          expect(
            Dox.serverUrl(Dox().server.httpServer),
            'https://127.0.0.1:$port',
          );

          HttpClientResponse res = await get('https', '/info');
          expect(res.statusCode, 200);
          expect(await body(res), 'https 1.1 https://localhost:$port/info');

          // SessionConfig.secure is null: the https scheme gives `Secure`
          HttpClientResponse session = await get('https', '/session');
          expect(await body(session), 'https');
          String? cookie = session.headers.value('set-cookie');
          expect(cookie, contains('dox_session='));
          expect(cookie, contains('; Secure'));
          expect(
            session.headers.value('strict-transport-security'),
            contains('max-age='),
          );
        },
      );

      test('tls on: a signed url with https is valid', () async {
        await start(config(tls: tls));
        int port = Dox().server.httpServer.port;
        String url = Route.signedUrl(
          'https.signed',
          baseUrl: 'https://localhost:$port',
        );
        String path = url.substring('https://localhost:$port'.length);
        HttpClientResponse ok = await get('https', path);
        expect(ok.statusCode, 200);
        expect(await body(ok), 'signed');

        HttpClientResponse changed = await get('https', '$path&user=2');
        await changed.drain<void>();
        expect(changed.statusCode, 403);
      });

      test('a trusted proxy that says http wins over tls', () async {
        await start(
          config(tls: tls, trustedProxies: <String>['127.0.0.1', '::1']),
        );
        HttpClientResponse res = await get(
          'https',
          '/session',
          forwardedProto: 'http',
        );
        expect(await body(res), 'http');
        String? cookie = res.headers.value('set-cookie');
        expect(cookie, contains('dox_session='));
        expect(cookie, isNot(contains('Secure')));
        expect(res.headers.value('strict-transport-security'), isNull);

        // no header from the proxy: the scheme of the TLS port
        HttpClientResponse direct = await get('https', '/session');
        expect(await body(direct), 'https');
      });

      test('X-Forwarded-Proto of an untrusted client is not used', () async {
        await start(config(tls: tls));
        HttpClientResponse res = await get(
          'https',
          '/session',
          forwardedProto: 'http',
        );
        expect(await body(res), 'https');
        expect(res.headers.value('set-cookie'), contains('; Secure'));
        expect(
          res.headers.value('strict-transport-security'),
          contains('max-age='),
        );
      });

      test('tls and http2 on: HTTP/2 over TLS (ALPN h2)', () async {
        await start(config(http2: true, tls: tls));
        SecureSocket socket = await open(<String>['h2', 'http/1.1']);
        expect(socket.selectedProtocol, 'h2');
        ClientTransportConnection c = ClientTransportConnection.viaSocket(
          socket,
        );
        ClientTransportStream s = c.makeRequest(<Header>[
          Header.ascii(':method', 'GET'),
          Header.ascii(':scheme', 'https'),
          Header.ascii(':path', '/info'),
          Header.ascii(':authority', 'localhost'),
        ], endStream: true);
        try {
          List<int> bytes = <int>[];
          await for (StreamMessage m in s.incomingMessages.timeout(_wait)) {
            if (m is DataStreamMessage) bytes.addAll(m.bytes);
          }
          expect(utf8.decode(bytes), 'https 2.0 https://localhost/info');
        } finally {
          await c.terminate();
          socket.destroy();
        }

        // HTTP/1.1 clients keep working on the port
        HttpClientResponse res = await get('https', '/info');
        expect(await body(res), startsWith('https 1'));
      });

      test('tls on, http2 off: the server offers only http/1.1', () async {
        await start(config(tls: tls));
        SecureSocket socket = await open(<String>['h2', 'http/1.1']);
        expect(socket.selectedProtocol, 'http/1.1');
        socket.destroy();
      });

      test('tls off: plain HTTP, http scheme, no Secure cookie', () async {
        // after the TLS servers of the other tests, in the same isolate
        await start(config());
        int port = Dox().server.httpServer.port;
        HttpClientResponse res = await get('http', '/info');
        expect(await body(res), 'http 1.1 http://localhost:$port/info');
        HttpClientResponse session = await get('http', '/session');
        await session.drain<void>();
        String? cookie = session.headers.value('set-cookie');
        expect(cookie, contains('dox_session='));
        expect(cookie, isNot(contains('Secure')));
        await expectLater(Dox().server.reloadCertificate(), throwsStateError);
      });

      test('a closed TLS server leaves the http scheme', () async {
        await start(config(tls: tls));
        expect(TrustedProxy.directScheme, 'https');
        await Dox().server.close(force: true);
        expect(TrustedProxy.directScheme, 'http');
        await expectLater(Dox().server.reloadCertificate(), throwsStateError);
      });

      test('a request open during shutdown stays https', () async {
        await start(config(tls: tls));
        int port = Dox().server.httpServer.port;
        slowEntered = Completer<void>();
        slowGate = Completer<void>();
        Future<HttpClientResponse> open = get('https', '/slow');
        await slowEntered.future.timeout(_wait);

        Future<void> stopped = Dox().server.shutdown(_wait);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        // the server drains: no reload, but the open request is still https
        await expectLater(Dox().server.reloadCertificate(), throwsStateError);
        slowGate.complete();

        HttpClientResponse res = await open;
        expect(await body(res), 'https https://localhost:$port/slow');
        expect(res.headers.value('set-cookie'), contains('; Secure'));
        client.close(force: true);
        await stopped.timeout(_wait);
        expect(TrustedProxy.directScheme, 'http');
      });

      test('DoxTestClient.certificateOf: no certificate in the file', () async {
        expect(DoxTestClient.certificateOf(tls.certificatePath), isNotEmpty);
        File bad = File('${dir.path}/bad.pem')..writeAsStringSync('junk');
        expect(
          () => DoxTestClient.certificateOf(bad.path),
          throwsA(
            isA<ArgumentError>().having(
              (ArgumentError e) => '$e',
              'text',
              contains(bad.path),
            ),
          ),
        );
      });

      test('reloadCertificate: new certificate, a bad file keeps it', () async {
        await start(config(tls: tls));
        SecureSocket old = await open(<String>['http/1.1']);
        expect(old.peerCertificate!.subject, contains('dox test 1'));

        await File('${made.path}/cert2.pem').copy(tls.certificatePath);
        await File('${made.path}/key2.pem').copy(tls.keyPath);
        await Dox().server.reloadCertificate();
        expect((await fresh('/info')).$1, contains('dox test 2'));

        // a bad file throws and keeps the certificate
        await File(tls.certificatePath).writeAsString('junk');
        await expectLater(
          Dox().server.reloadCertificate(),
          throwsA(isA<TlsException>()),
        );
        expect((await fresh('/info')).$1, contains('dox test 2'));
        old.destroy();
      });

      test('a bad certificate file throws when the server starts', () async {
        await expectLater(
          start(
            config(
              tls: TlsOptions(
                certificatePath: '${dir.path}/none.pem',
                keyPath: tls.keyPath,
              ),
            ),
          ),
          throwsA(isA<TlsException>()),
        );
      });

      test('2 isolates, a bad file: one error, no isolate starts', () async {
        await expectLater(
          start(
            config(
              totalIsolate: 2,
              port: await freePort(),
              tls: TlsOptions(
                certificatePath: '${dir.path}/none.pem',
                keyPath: tls.keyPath,
              ),
            ),
          ),
          throwsA(isA<TlsException>()),
        );
        expect(DoxIsolate().isolates, isEmpty);
      });

      test(
        '2 isolates: HTTPS works, one reloadCertificate reaches both',
        // Windows runs one isolate
        skip: Platform.isWindows,
        () async {
          await start(
            config(totalIsolate: 2, port: await freePort(), tls: tls),
          );
          // the other isolate sends its port when its server listens
          DateTime end = DateTime.now().add(_wait);
          while (DoxIsolate().sendPorts.isEmpty) {
            expect(DateTime.now().isBefore(end), isTrue, reason: 'isolate 2');
            await Future<void>.delayed(const Duration(milliseconds: 20));
          }
          expect((await fresh('/isolate')).$1, contains('dox test 1'));

          await File('${made.path}/cert2.pem').copy(tls.certificatePath);
          await File('${made.path}/key2.pem').copy(tls.keyPath);
          await Dox().server.reloadCertificate();

          Set<String> served = <String>{};
          for (int i = 0; i < 40; i++) {
            (String, String) got = await fresh('/isolate');
            expect(got.$1, contains('dox test 2'), reason: 'request $i');
            served.add(got.$2);
          }
          // Linux spreads new connections over the isolates
          // (SO_REUSEPORT). macOS sends them all to one isolate.
          if (Platform.isLinux) {
            expect(served, <String>{'1', '2'});
          }
        },
      );

      test('DoxTestClient speaks HTTPS and trusts only the config', () async {
        DoxTestClient test = await DoxTestClient.start(config(tls: tls));
        started = true;
        expect(test.baseUri.scheme, 'https');
        (await test.get('/info'))
            .expectStatus(200)
            .expectBody(startsWith('https 1.1 https://127.0.0.1:'));
        await test.close();
        started = false;

        // the server gets another certificate than the one of the config
        DoxTestClient other = await DoxTestClient.start(config(tls: tls));
        started = true;
        await File('${made.path}/cert2.pem').copy(tls.certificatePath);
        await File('${made.path}/key2.pem').copy(tls.keyPath);
        await Dox().server.reloadCertificate();
        await expectLater(
          other.get('/info'),
          throwsA(isA<HandshakeException>()),
        );
        await other.close();
        started = false;
      });
    },
  );
}
