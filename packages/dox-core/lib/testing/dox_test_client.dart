import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dox_core/dox_core.dart';
import 'package:dox_core/server/dox_server.dart';

import 'test_response.dart';

/// Sends requests to your app in tests.
///
/// [start] runs the app in the test, on `127.0.0.1` and a free port the OS
/// picks. So many test files can run at the same time.
/// ```
/// late DoxTestClient client;
///
/// setUpAll(() async {
///   client = await DoxTestClient.start(appConfig);
/// });
///
/// tearDownAll(() async {
///   await client.close();
/// });
///
/// test('ping', () async {
///   TestResponse res = await client.get('/api/ping');
///   res.expectStatus(200).expectBody('pong');
/// });
/// ```
class DoxTestClient {
  /// a client for a server that already runs at [baseUri]
  DoxTestClient(this.baseUri, {Map<String, String>? headers})
    : headers = Map<String, String>.unmodifiable(
        headers ?? const <String, String>{},
      ),
      _http = HttpClient(),
      _jar = null;

  DoxTestClient._copy(this.baseUri, this.headers, this._http, this._jar);

  /// the url of the server, eg. `http://127.0.0.1:53211`
  final Uri baseUri;

  /// headers sent with every request of this client
  final Map<String, String> headers;

  final HttpClient _http;

  /// the cookies of a [withSession] client, else null
  final Map<String, String>? _jar;

  /// the cookies this client keeps (name to raw value). Empty when it is
  /// not a [withSession] client. You can change them.
  Map<String, String> get cookies => _jar ?? <String, String>{};

  /// Start the app of [config] in this isolate and give a client for it.
  ///
  /// It runs the services (eg. the ORM service) and registers the routes,
  /// like the real start. It always listens on `127.0.0.1` and a free
  /// port, and runs one isolate. `serverPort` and `totalIsolate` of
  /// [config] are not used.
  static Future<DoxTestClient> start(AppConfig config) async {
    Dox dox = Dox();
    dox.initialize(config);
    dox.addServices(config.services);
    await dox.startServices();
    DoxServer server = DoxServer();
    server.setResponseHandler(config.responseHandler);
    HttpServer http = await server.listen(
      0,
      address: InternetAddress.loopbackIPv4,
    );
    return DoxTestClient(Uri.parse('http://127.0.0.1:${http.port}'));
  }

  /// Stop the server of [start] (and its `DoxShutdown` services), and
  /// close this client.
  Future<void> close() async {
    _http.close(force: true);
    await Dox().stopIsolate();
  }

  /// a copy of this client that also sends [values] with every request
  DoxTestClient withHeaders(Map<String, String> values) {
    return DoxTestClient._copy(
      baseUri,
      Map<String, String>.unmodifiable(<String, String>{...headers, ...values}),
      _http,
      _jar,
    );
  }

  /// a copy of this client that sends `Authorization: Bearer <token>`.
  /// ```
  /// TestResponse res = await client.withToken(token).get('/api/me');
  /// ```
  DoxTestClient withToken(String token) {
    return withHeaders(<String, String>{
      HttpHeaders.authorizationHeader: 'Bearer $token',
    });
  }

  /// a copy of this client that sends [values] as cookies. Use the
  /// `cookies` of a response to go on with its session.
  /// ```
  /// TestResponse login = await client.post('/login', body: form);
  /// DoxTestClient user = client.withCookies(login.cookies);
  /// ```
  DoxTestClient withCookies(Map<String, String> values) {
    return withHeaders(<String, String>{
      HttpHeaders.cookieHeader: <String>[
        for (MapEntry<String, String> c in values.entries)
          '${c.key}=${c.value}',
      ].join('; '),
    });
  }

  /// A copy of this client that works like a browser with a session:
  /// - it keeps the cookies of every response (`Set-Cookie`) and sends
  ///   them back. A cookie with an empty value, `Max-Age=0` or an old
  ///   `Expires` date is removed.
  /// - on `POST`, `PUT`, `PATCH` and `DELETE` it sends the `XSRF-TOKEN`
  ///   cookie in the `X-XSRF-TOKEN` header, like axios and Inertia. So
  ///   `CsrfMiddleware` lets the request in.
  ///
  /// Each call gives a new browser with no cookies. Copies made from it
  /// (eg. with [withHeaders]) share its cookies.
  /// ```
  /// DoxTestClient browser = client.withSession();
  /// await browser.get('/login'); // gets the session and XSRF-TOKEN cookies
  /// TestResponse res = await browser.post('/login', body: form);
  /// res.expectStatus(302).expectHeader('location', '/dashboard');
  /// (await browser.get('/dashboard')).expectStatus(200);
  /// ```
  DoxTestClient withSession() {
    return DoxTestClient._copy(baseUri, headers, _http, <String, String>{});
  }

  Future<TestResponse> get(String path, {Map<String, String>? headers}) {
    return send('GET', path, headers: headers);
  }

  Future<TestResponse> post(
    String path, {
    Object? body,
    Map<String, String>? headers,
  }) {
    return send('POST', path, body: body, headers: headers);
  }

  Future<TestResponse> put(
    String path, {
    Object? body,
    Map<String, String>? headers,
  }) {
    return send('PUT', path, body: body, headers: headers);
  }

  Future<TestResponse> patch(
    String path, {
    Object? body,
    Map<String, String>? headers,
  }) {
    return send('PATCH', path, body: body, headers: headers);
  }

  Future<TestResponse> delete(
    String path, {
    Object? body,
    Map<String, String>? headers,
  }) {
    return send('DELETE', path, body: body, headers: headers);
  }

  /// Send a request. [path] can have a query, eg. `/users?page=2`.
  ///
  /// A `String` or `List<int>` [body] is sent as it is. Any other body
  /// (eg. a Map) is sent as JSON, with `Content-Type: application/json`.
  /// Redirects are not followed, so you can check them.
  Future<TestResponse> send(
    String method,
    String path, {
    Object? body,
    Map<String, String>? headers,
  }) async {
    HttpClientRequest request = await _http.openUrl(
      method,
      baseUri.resolve(path),
    );
    request.followRedirects = false;
    List<int>? bytes;
    if (body is List<int>) {
      bytes = body;
    } else if (body is String) {
      bytes = utf8.encode(body);
    } else if (body != null) {
      bytes = utf8.encode(jsonEncode(body));
      request.headers.contentType = ContentType.json;
    }
    Map<String, String> all = <String, String>{...this.headers, ...?headers};
    Map<String, String>? jar = _jar;
    if (jar != null) _addJar(jar, method, all);
    for (MapEntry<String, String> header in all.entries) {
      request.headers.set(header.key, header.value);
    }
    if (bytes != null) {
      request.contentLength = bytes.length;
      request.add(bytes);
    }
    HttpClientResponse response = await request.close();
    BytesBuilder data = BytesBuilder(copy: false);
    await for (List<int> chunk in response) {
      data.add(chunk);
    }
    if (jar != null) _keep(jar, response.cookies);
    Map<String, String> found = <String, String>{};
    response.headers.forEach((String name, List<String> values) {
      found[name.toLowerCase()] = values.join(', ');
    });
    return TestResponse(
      response.statusCode,
      found,
      data.takeBytes(),
      cookies: <String, String>{
        for (Cookie cookie in response.cookies) cookie.name: cookie.value,
      },
    );
  }

  static const Set<String> _unsafe = <String>{'POST', 'PUT', 'PATCH', 'DELETE'};

  /// adds the cookies of [jar] (and the XSRF header) to [all]
  static void _addJar(
    Map<String, String> jar,
    String method,
    Map<String, String> all,
  ) {
    if (jar.isEmpty) return;
    String? own = all[HttpHeaders.cookieHeader];
    all[HttpHeaders.cookieHeader] = <String>[
      for (MapEntry<String, String> c in jar.entries) '${c.key}=${c.value}',
      ?own,
    ].join('; ');
    String? token = jar['XSRF-TOKEN'];
    if (token != null && _unsafe.contains(method.toUpperCase())) {
      all.putIfAbsent('X-XSRF-TOKEN', () => Uri.decodeComponent(token));
    }
  }

  /// saves the [found] cookies in [jar], and removes deleted ones
  static void _keep(Map<String, String> jar, List<Cookie> found) {
    DateTime now = DateTime.now();
    for (Cookie cookie in found) {
      int? maxAge = cookie.maxAge;
      DateTime? expires = cookie.expires;
      bool gone =
          cookie.value.isEmpty ||
          (maxAge != null && maxAge <= 0) ||
          (maxAge == null && expires != null && !expires.isAfter(now));
      if (gone) {
        jar.remove(cookie.name);
      } else {
        jar[cookie.name] = cookie.value;
      }
    }
  }
}
