import 'package:dox_core/dox_core.dart';

part 'app_env.g.dart';

/// A typed env class for the env tests. Run `dart run build_runner build`
/// in packages/dox-core after you change it.
@DoxEnv()
abstract class AppEnv {
  static AppEnv load([EnvReader? reader]) {
    return _$AppEnv.load(reader);
  }

  String get appEnv => 'production';

  int get appPort => 3000;

  /// a default that uses another getter
  String get appUrl => 'http://localhost:$appPort';

  String? get region => null;

  /// these names are also locals in the generated load()
  String? get r;

  String? get reader;

  /// throws when BROKEN is missing, to test that load() still fails
  String get broken {
    if (appEnv == 'broken') throw StateError('bad default');
    return 'ok';
  }
}
