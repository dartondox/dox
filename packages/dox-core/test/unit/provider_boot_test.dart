import 'package:dox_core/dox_core.dart';
import 'package:test/test.dart';

/// what the providers did, in order
List<String> _steps = <String>[];

class _First extends DoxProvider {
  @override
  void setup() => _steps.add('setup first');

  /// async: the next boot() waits for it
  @override
  Future<void> boot() async {
    await Future<void>.delayed(const Duration(milliseconds: 10));
    _steps.add('boot first');
  }
}

/// a slow provider
class _Second extends DoxProvider {
  @override
  Future<void> setup() async {
    await Future<void>.delayed(const Duration(milliseconds: 10));
    _steps.add('setup second');
  }

  @override
  void boot() => _steps.add('boot second');
}

class _Broken extends DoxProvider {
  @override
  void setup() => _steps.add('setup broken');

  @override
  void boot() => throw StateError('boot failed');
}

Future<void> _start(List<DoxProvider> providers) async {
  _steps.clear();
  Dox().initialize(
    AppConfig(appKey: '4HyiSrq4N5Nfg6bOadIhbFEI8zbUkpxt', providers: providers),
  );
  Dox().doxProviders.clear();
  Dox().addProviders(Dox().config.providers);
  await Dox().startProviders();
}

void main() {
  test(
    'boot() runs after setup() of every provider, awaited in order',
    () async {
      await _start(<DoxProvider>[_First(), _Second()]);
      expect(_steps, <String>[
        'setup first',
        'setup second',
        'boot first',
        'boot second',
      ]);
    },
  );

  test(
    'a boot() that throws fails the start, the next boot() does not run',
    () async {
      await expectLater(
        _start(<DoxProvider>[_Broken(), _Second()]),
        throwsA(isA<StateError>()),
      );
      expect(_steps, <String>['setup broken', 'setup second']);
    },
  );
}
