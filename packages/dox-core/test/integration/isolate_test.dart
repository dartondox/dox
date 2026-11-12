import 'dart:io';
import 'dart:isolate';

import 'package:dox_core/dox_core.dart';
import 'package:dox_core/isolate/dox_isolate.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

import '../utils/free_port.dart';
import 'requirements/config/api_router.dart';
import 'requirements/handler.dart';

AppConfig isolateConfig(int port) => AppConfig(
  /// application key
  appKey: '4HyiSrq4N5Nfg6bOadIhbFEI8zbUkpxt',

  /// a free port, known before the start: all 5 isolates share it.
  /// Port 0 would give each isolate its own port.
  serverPort: port,

  /// total multi-thread isolate to run
  totalIsolate: 1,

  /// response handler
  responseHandler: ResponseHandler(),

  /// routers
  routers: <Router>[ApiRouter()],
);

late String baseUrl;

class ExampleProvider extends DoxProvider {
  /// every other isolate answers a 'ping' on the bus with its id
  @override
  void setup() {
    if (Dox().isolateId == 1) return;
    IsolateBus.instance.on('ping').listen((Object? _) {
      IsolateBus.instance.publish('pong', Dox().isolateId);
    });
    IsolateBus.instance.on('env').listen((Object? _) {
      IsolateBus.instance.publish(
        'env-value',
        '${Dox().isolateId}:${Env.get<String>('DOX_EXPAND_B')}',
      );
    });
  }
}

/// waits until [test] is true, for at most two seconds
Future<void> _until(bool Function() test) async {
  for (int i = 0; i < 100 && !test(); i++) {
    await Future<void>.delayed(Duration(milliseconds: 20));
  }
  expect(test(), isTrue);
}

void main() {
  late Directory publicDir;

  group('Isolate', () {
    setUpAll(() async {
      /// before anything reads .env, like the top of main()
      Env.flags = const CoreFlags(envExpand: true);

      /// added before startServer and outside a Router, so only the
      /// spawn parameter brings it to the other isolates
      publicDir = await Directory.systemTemp.createTemp('dox_isolate_static_');
      await File('${publicDir.path}/app.css').writeAsString('a{}');
      Route.staticFiles('/', publicDir.path);

      int port = await freePort();
      baseUrl = 'http://localhost:$port';
      Dox().initialize(isolateConfig(port));
      Dox().addProvider(ExampleProvider());
      Dox().totalIsolate(5);
      await Dox().startServer();
    });

    tearDownAll(() async {
      DoxIsolate().killAll();
      await Dox().server.close();
      await publicDir.delete(recursive: true);
    });

    test('static files work in every isolate', () async {
      /// http.get opens a new connection each time, so the requests
      /// go to different isolates
      for (int i = 0; i < 50; i++) {
        http.Response res = await http.get(Uri.parse('$baseUrl/app.css'));
        expect(res.statusCode, 200, reason: 'request $i');
        expect(res.body, 'a{}');
      }
    });

    test('test', () async {
      Uri url = Uri.parse('$baseUrl/api/ping');
      http.Response res = await http.get(url);

      expect(res.statusCode, 200);
      expect(res.body, 'pong');
      expect(DoxIsolate().isolates.length, 5 - 1);
    });

    test('dead isolate is started again', () async {
      DoxIsolate().restartDelay = Duration(milliseconds: 10);
      Isolate old = DoxIsolate().isolates[2]!;
      old.kill(priority: Isolate.immediate);

      Isolate? fresh;
      for (int i = 0; i < 100 && fresh == null; i++) {
        await Future<void>.delayed(Duration(milliseconds: 20));
        Isolate? current = DoxIsolate().isolates[2];
        if (current != null && current != old) fresh = current;
      }
      expect(fresh, isNotNull);
      expect(DoxIsolate().isolates.length, 5 - 1);
    });

    test('the bus drops a dead isolate and the new one joins', () async {
      // long enough to see the drop before the restart
      DoxIsolate().restartDelay = Duration(milliseconds: 500);
      IsolateBus bus = IsolateBus.instance;
      Set<Object?> pongs = <Object?>{};
      bus.on('pong').listen(pongs.add);
      await _until(() => bus.size == 5);

      Isolate old = DoxIsolate().isolates[3]!;
      old.kill(priority: Isolate.immediate);
      await _until(() => bus.size == 4);

      // started again: it joins the bus in the setup of the provider
      await _until(() {
        Isolate? fresh = DoxIsolate().isolates[3];
        return fresh != null && fresh != old && bus.size == 5;
      });
      bus.publish('ping', null);
      await _until(() => pongs.length == 4);
      expect(pongs, <Object?>{2, 3, 4, 5});
    });

    test('every isolate reads .env with envExpand', () async {
      expect(Env.get<String>('DOX_EXPAND_B'), 'xy');
      IsolateBus bus = IsolateBus.instance;
      Set<Object?> values = <Object?>{};
      bus.on('env-value').listen(values.add);
      await _until(() => bus.size == 5);
      bus.publish('env', null);
      await _until(() => values.length == 4);
      expect(values, <Object?>{'2:xy', '3:xy', '4:xy', '5:xy'});
    });

    test('default isolates is one per cpu core', () {
      expect(AppConfig(appKey: 'x').totalIsolate, Platform.numberOfProcessors);
    });
  });
}
