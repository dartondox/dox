import 'package:dox_core/dox_core.dart';
import 'package:test/test.dart';

class _Probe extends DoxProvider {
  static bool? seen;

  @override
  void setup() => seen = Dox().isWebServer;
}

void main() {
  test('isWebServer is false until the web server starts', () async {
    expect(Dox().isWebServer, isFalse);
    Dox().initialize(
      AppConfig(
        appKey: '4HyiSrq4N5Nfg6bOadIhbFEI8zbUkpxt',
        serverPort: 0,
        totalIsolate: 1,
        providers: <DoxProvider>[_Probe()],
      ),
    );
    // like bin/queue.dart: only the providers run
    Dox().addProviders(Dox().config.providers);
    await Dox().startProviders();
    expect(_Probe.seen, isFalse);

    Dox().doxProviders.clear();
    await Dox().startServer();
    expect(_Probe.seen, isTrue);
    expect(Dox().isWebServer, isTrue);
    await Dox().server.close(force: true);
  });
}
