import 'dart:convert';
import 'dart:io';

/// Streams one multipart upload of `mb` MB to the server and prints the
/// server's peak RSS afterwards.
/// Usage: dart run benchmark/`upload.dart <baseUrl> [mb=50] [path=/upload]`
void main(List<String> args) async {
  String base = args[0];
  int mb = args.length > 1 ? int.parse(args[1]) : 50;
  String path = args.length > 2 ? args[2] : '/upload';
  String boundary = 'doxbenchboundary';
  List<int> head = utf8.encode(
    '--$boundary\r\n'
    'Content-Disposition: form-data; name="file"; filename="big.bin"\r\n'
    'Content-Type: application/octet-stream\r\n\r\n',
  );
  List<int> tail = utf8.encode('\r\n--$boundary--\r\n');
  List<int> chunk = List<int>.filled(1024 * 1024, 120);

  HttpClient client = HttpClient();
  HttpClientRequest req = await client.postUrl(Uri.parse('$base$path'));
  req.headers.contentType = ContentType(
    'multipart',
    'form-data',
    parameters: <String, String>{'boundary': boundary},
  );
  req.contentLength = head.length + tail.length + chunk.length * mb;
  req.add(head);
  for (int i = 0; i < mb; i++) {
    req.add(chunk);
    await req.flush();
  }
  req.add(tail);
  Stopwatch sw = Stopwatch()..start();
  HttpClientResponse res = await req.close();
  String body = await utf8.decodeStream(res);
  print('upload ${res.statusCode} $body in ${sw.elapsedMilliseconds}ms');

  HttpClientResponse rss = await (await client.getUrl(Uri.parse('$base/rss')))
      .close();
  print('server ${await utf8.decodeStream(rss)}');
  client.close();
}
