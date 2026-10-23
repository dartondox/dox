import 'dart:io';

/// Docker health check. The final image has no shell and no curl,
/// so this small binary asks the app itself. Exit 0 = healthy.
Future<void> main() async {
  String port = Platform.environment['APP_PORT'] ?? '3000';
  HttpClient client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 3);
  try {
    HttpClientRequest request = await client.getUrl(
      Uri.parse('http://127.0.0.1:$port/health'),
    );
    HttpClientResponse response = await request.close();
    exit(response.statusCode == 200 ? 0 : 1);
  } catch (_) {
    exit(1);
  }
}
