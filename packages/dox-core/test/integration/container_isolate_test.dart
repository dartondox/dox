import 'package:dox_core/dox_core.dart';
import 'package:dox_core/isolate/dox_isolate.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

import '../utils/free_port.dart';
import 'requirements/container/app.dart';

void main() {
  late String baseUrl;

  setUpAll(() async {
    int port = await freePort();
    baseUrl = 'http://localhost:$port';
    Dox().initialize(containerConfig(port: port, isolates: 3));
    await Dox().startServer();
  });

  tearDownAll(() async {
    DoxIsolate().killAll();
    await Dox().server.close();
  });

  test('every isolate has its own container and one controller', () async {
    Map<String, Set<String>> byIsolate = <String, Set<String>>{};
    for (int i = 0; i < 60; i++) {
      http.Response users = await http.get(Uri.parse('$baseUrl/api/users/1'));
      expect(users.body, 'user 1');
      http.Response res = await http.get(Uri.parse('$baseUrl/api/hash'));
      List<String> parts = res.body.split(':');
      (byIsolate[parts[0]] ??= <String>{}).add(parts[1]);
    }
    for (Set<String> hashes in byIsolate.values) {
      expect(hashes.length, 1);
    }
  });
}
