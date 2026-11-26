import 'dart:convert';
import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:http2/http2.dart';
import 'package:test/test.dart';

import '../utils/start_http_server.dart';
import '../utils/test_app_key.dart';

/// Time for one request. The full test run is busy, so it is generous.
const Duration _wait = Duration(seconds: 20);

/// Makes a self-signed certificate for `localhost` and `127.0.0.1` with
/// the name `dox test <n>`: `cert<n>.pem` and `key<n>.pem` in [dir]. Short
/// lived (macOS trusts no server certificate of more than 825 days).
void makeCertificate(Directory dir, int n) {
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
  expect(made.exitCode, 0, reason: '${made.stderr}');
}

/// The certificates are self-signed, so the check of the system fails.
/// The tests read the name of the certificate where it matters.
bool trusted(X509Certificate cert) => cert.subject.contains('dox test');

bool trustedFor(X509Certificate cert, String host, int port) => trusted(cert);

void main() {
  late Directory made;
  late Directory dir;
  late TlsOptions tls;
  late HttpClient client;

  setUpAll(() {
    made = Directory.systemTemp.createTempSync('dox_core_https_certs_');
    makeCertificate(made, 1);
    makeCertificate(made, 2);
    Route.get('/info', (DoxRequest req) {
      return '${req.scheme()} ${req.protocolVersion} ${req.fullUrl()}';
    });
    Route.get('/session', <dynamic>[
      const SessionMiddleware(),
      (DoxRequest req) {
        req.session.put('name', 'dox');
        return 'ok';
      },
    ]);
  });

  tearDownAll(() => made.deleteSync(recursive: true));

  setUp(() async {
    // copies, so the reload test can change them
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
    await Dox().server.close(force: true);
    await dir.delete(recursive: true);
  });

  Future<void> start({bool http2 = false, TlsOptions? tls}) {
    return startHttpServer(
      AppConfig(
        appKey: testAppKey,
        serverPort: 0,
        totalIsolate: 1,
        host: '127.0.0.1',
        http2: http2,
        tls: tls,
      ),
    );
  }

  Future<HttpClientResponse> get(String scheme, String path) async {
    int port = Dox().server.httpServer.port;
    HttpClientRequest req = await client
        .getUrl(Uri.parse('$scheme://localhost:$port$path'))
        .timeout(_wait);
    return req.close().timeout(_wait);
  }

  Future<SecureSocket> open(List<String> alpn) => SecureSocket.connect(
    'localhost',
    Dox().server.httpServer.port,
    onBadCertificate: trusted,
    supportedProtocols: alpn,
  ).timeout(_wait);

  test('tls on: HTTPS over HTTP/1.1, https scheme, Secure cookie', () async {
    await start(tls: tls);
    int port = Dox().server.httpServer.port;
    expect(Dox.serverUrl(Dox().server.httpServer), 'https://127.0.0.1:$port');

    HttpClientResponse info = await get('https', '/info');
    expect(info.statusCode, 200);
    expect(
      await utf8.decodeStream(info).timeout(_wait),
      'https 1.1 https://localhost:$port/info',
    );

    // SessionConfig.secure is null: the https scheme gives `Secure`
    HttpClientResponse session = await get('https', '/session');
    await session.drain<void>();
    String? cookie = session.headers.value('set-cookie');
    expect(cookie, contains('dox_session='));
    expect(cookie, contains('; Secure'));
  });

  test('tls and http2 on: HTTP/2 over TLS (ALPN h2)', () async {
    await start(http2: true, tls: tls);
    SecureSocket socket = await open(<String>['h2', 'http/1.1']);
    expect(socket.selectedProtocol, 'h2');
    ClientTransportConnection c = ClientTransportConnection.viaSocket(socket);
    ClientTransportStream s = c.makeRequest(<Header>[
      Header.ascii(':method', 'GET'),
      Header.ascii(':scheme', 'https'),
      Header.ascii(':path', '/info'),
      Header.ascii(':authority', 'localhost'),
    ], endStream: true);
    try {
      List<int> body = <int>[];
      await for (StreamMessage m in s.incomingMessages.timeout(_wait)) {
        if (m is DataStreamMessage) body.addAll(m.bytes);
      }
      expect(utf8.decode(body), 'https 2.0 https://localhost/info');
    } finally {
      await c.terminate();
      socket.destroy();
    }

    // HTTP/1.1 clients keep working on the port
    HttpClientResponse info = await get('https', '/info');
    expect(await utf8.decodeStream(info).timeout(_wait), startsWith('https 1'));
  });

  test('tls on, http2 off: the server offers only http/1.1', () async {
    await start(tls: tls);
    SecureSocket socket = await open(<String>['h2', 'http/1.1']);
    expect(socket.selectedProtocol, 'http/1.1');
    socket.destroy();
  });

  test('tls off: plain HTTP, http scheme, no Secure cookie', () async {
    // after the TLS servers of the other tests, in the same isolate
    await start();
    int port = Dox().server.httpServer.port;
    HttpClientResponse info = await get('http', '/info');
    expect(
      await utf8.decodeStream(info).timeout(_wait),
      'http 1.1 http://localhost:$port/info',
    );
    HttpClientResponse session = await get('http', '/session');
    await session.drain<void>();
    String? cookie = session.headers.value('set-cookie');
    expect(cookie, contains('dox_session='));
    expect(cookie, isNot(contains('Secure')));
    await expectLater(Dox().server.reloadCertificate(), throwsStateError);
  });

  test('reloadCertificate: new certificate, a bad file keeps it', () async {
    await start(tls: tls);
    SecureSocket old = await open(<String>['http/1.1']);
    expect(old.peerCertificate!.subject, contains('dox test 1'));

    await File('${made.path}/cert2.pem').copy(tls.certificatePath);
    await File('${made.path}/key2.pem').copy(tls.keyPath);
    await Dox().server.reloadCertificate();
    SecureSocket fresh = await open(<String>['http/1.1']);
    expect(fresh.peerCertificate!.subject, contains('dox test 2'));

    // a bad file throws and keeps the certificate
    await File(tls.certificatePath).writeAsString('junk');
    await expectLater(
      Dox().server.reloadCertificate(),
      throwsA(isA<TlsException>()),
    );
    SecureSocket after = await open(<String>['http/1.1']);
    expect(after.peerCertificate!.subject, contains('dox test 2'));
    old.destroy();
    fresh.destroy();
    after.destroy();
  });

  test('a bad certificate file throws when the server starts', () async {
    await expectLater(
      start(
        tls: TlsOptions(
          certificatePath: '${dir.path}/none.pem',
          keyPath: tls.keyPath,
        ),
      ),
      throwsA(isA<TlsException>()),
    );
    // the tearDown closes a server: give it one
    await start();
  });
}
