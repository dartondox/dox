import 'package:dox_core/dox_core.dart';

part 'loop_env.g.dart';

/// An env class with a bad default: it reads the global [loopEnv], not
/// the getter. For the env tests.
@DoxEnv()
abstract class LoopEnv {
  static LoopEnv load([EnvReader? reader]) {
    return _$LoopEnv.load(reader);
  }

  String get appEnv => 'production';

  bool get isDevelopment => loopEnv.appEnv == 'development';
}

final LoopEnv loopEnv = LoopEnv.load(
  EnvReader(
    environment: const <String, String>{},
    dotEnv: const <String, String>{},
  ),
);
