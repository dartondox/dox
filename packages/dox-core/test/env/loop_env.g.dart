// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'loop_env.dart';

// **************************************************************************
// Generator: DoxEnvBuilder
// **************************************************************************

class _$LoopEnv extends LoopEnv {
  _$LoopEnv._({required String? appEnv, required bool? isDevelopment})
    : _$appEnv = appEnv,
      _$isDevelopment = isDevelopment;

  final String? _$appEnv;
  @override
  late final String appEnv = _$appEnv ?? super.appEnv;
  final bool? _$isDevelopment;
  @override
  late final bool isDevelopment = _$isDevelopment ?? super.isDevelopment;

  /// true while [load] runs. A default that reads the global `env` calls
  /// [load] again, and would loop until the stack overflows.
  static bool _$$loading = false;

  /// reads and checks every key once. Throws `EnvException` with all
  /// missing or bad keys. Then works out every default once, so a default
  /// that throws stops the app here, at startup.
  static LoopEnv load([EnvReader? $reader]) {
    if (_$$loading) {
      throw StateError(
        'A default of LoopEnv reads the global `env`. Use the getter directly: write `appEnv`, not `env.appEnv`.',
      );
    }
    _$$loading = true;
    try {
      EnvReader $r = $reader ?? EnvReader();
      String? appEnv = $r.string('APP_ENV');
      bool? isDevelopment = $r.boolean('IS_DEVELOPMENT');

      $r.check();
      _$LoopEnv $env = _$LoopEnv._(
        appEnv: appEnv,
        isDevelopment: isDevelopment,
      );
      $env.appEnv;
      $env.isDevelopment;

      return $env;
    } finally {
      _$$loading = false;
    }
  }
}
