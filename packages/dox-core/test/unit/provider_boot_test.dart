import 'package:dox_core/dox_core.dart';
import 'package:test/test.dart';

/// what the providers did, in order
List<String> _steps = <String>[];

class _First extends DoxProvider {
  @override
  void setup() => _steps.add('setup first');

  @override
  void boot() => _steps.add('boot first');
}

/// a slow provider without boot()
class _Second extends DoxProvider {
  @override
  Future<void> setup() async {
    await Future<void>.delayed(const Duration(milliseconds: 10));
    _steps.add('setup second');
  }
}

void main() {
  test('boot() runs after setup() of every provider', () async {
    Dox().initialize(
      AppConfig(
        appKey: '4HyiSrq4N5Nfg6bOadIhbFEI8zbUkpxt',
        providers: <DoxProvider>[_First(), _Second()],
      ),
    );
    Dox().addProviders(Dox().config.providers);
    await Dox().startProviders();
    expect(_steps, <String>['setup first', 'setup second', 'boot first']);
  });
}
