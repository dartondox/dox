import 'dart:async';
import 'dart:io';
import 'dart:isolate';

/// Tiny keep-alive HTTP load generator (no wrk/oha needed).
/// Usage: dart run benchmark/`load.dart <url> [connections=64] [seconds=10] [workers=4]`
void main(List<String> args) async {
  Uri url = Uri.parse(args[0]);
  int connections = args.length > 1 ? int.parse(args[1]) : 64;
  int seconds = args.length > 2 ? int.parse(args[2]) : 10;
  int workers = args.length > 3 ? int.parse(args[3]) : 4;

  ReceivePort port = ReceivePort();
  for (int i = 0; i < workers; i++) {
    await Isolate.spawn(_worker, <dynamic>[
      port.sendPort,
      url,
      connections ~/ workers,
      seconds,
    ]);
  }

  int total = 0;
  int errors = 0;
  List<int> latencies = <int>[];
  int done = 0;
  await for (dynamic msg in port) {
    List<dynamic> m = msg as List<dynamic>;
    total += m[0] as int;
    errors += m[1] as int;
    latencies.addAll((m[2] as List<dynamic>).cast<int>());
    if (++done == workers) break;
  }
  port.close();
  latencies.sort();
  int p(double q) =>
      latencies.isEmpty ? 0 : latencies[(latencies.length * q).floor()];
  print(
    'requests/s: ${(total / seconds).round()}  '
    'p50: ${p(0.5) / 1000}ms  p99: ${p(0.99) / 1000}ms  errors: $errors',
  );
}

Future<void> _worker(List<dynamic> a) async {
  SendPort out = a[0];
  Uri url = a[1];
  int conns = a[2];
  int seconds = a[3];
  HttpClient client = HttpClient()..maxConnectionsPerHost = conns;
  DateTime end = DateTime.now().add(Duration(seconds: seconds));
  int count = 0;
  int errors = 0;
  List<int> lat = <int>[];

  Future<void> loop() async {
    Stopwatch sw = Stopwatch();
    while (DateTime.now().isBefore(end)) {
      sw
        ..reset()
        ..start();
      try {
        HttpClientRequest req = await client.getUrl(url);
        HttpClientResponse res = await req.close();
        await res.drain<void>();
        if (res.statusCode != 200) errors++;
        count++;
        if (count % 10 == 0) lat.add(sw.elapsedMicroseconds);
      } catch (_) {
        errors++;
      }
    }
  }

  await Future.wait(List<Future<void>>.generate(conns, (_) => loop()));
  client.close(force: true);
  out.send(<dynamic>[count, errors, lat]);
}
