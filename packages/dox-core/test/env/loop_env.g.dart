// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'loop_env.dart';

// **************************************************************************
// Generator: DoxEnvBuilder
// **************************************************************************

class _$LoopEnv extends LoopEnv {
  _$LoopEnv._({required int? appPort, required String? appUrl})
    : _$appPort = appPort,
      _$appUrl = appUrl;

  final int? _$appPort;
  @override
  late final int appPort = _$appPort ?? super.appPort;
  final String? _$appUrl;
  @override
  late final String appUrl = _$appUrl ?? super.appUrl;

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
      int? appPort = $r.integer('APP_PORT');
      String? appUrl = $r.string('APP_URL');

      $r.check();
      _$LoopEnv $env = _$LoopEnv._(appPort: appPort, appUrl: appUrl);
      $env.appPort;
      $env.appUrl;

      return $env;
    } finally {
      _$$loading = false;
    }
  }
}
