// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_env.dart';

// **************************************************************************
// Generator: DoxEnvBuilder
// **************************************************************************

class _$AppEnv extends AppEnv {
  _$AppEnv._({
    required String? appEnv,
    required int? appPort,
    required String? appUrl,
    required String? region,
    required this.r,
    required this.reader,
    required String? broken,
  }) : _$appEnv = appEnv,
       _$appPort = appPort,
       _$appUrl = appUrl,
       _$region = region,
       _$broken = broken;

  final String? _$appEnv;
  @override
  late final String appEnv = _$appEnv ?? super.appEnv;
  final int? _$appPort;
  @override
  late final int appPort = _$appPort ?? super.appPort;
  final String? _$appUrl;
  @override
  late final String appUrl = _$appUrl ?? super.appUrl;
  final String? _$region;
  @override
  late final String? region = _$region ?? super.region;
  @override
  final String? r;
  @override
  final String? reader;
  final String? _$broken;
  @override
  late final String broken = _$broken ?? super.broken;

  /// true while [load] runs. A default that reads the global `env` calls
  /// [load] again, and would loop until the stack overflows.
  static bool _$$loading = false;

  /// reads and checks every key once. Throws `EnvException` with all
  /// missing or bad keys. Then works out every default once, so a default
  /// that throws stops the app here, at startup.
  static AppEnv load([EnvReader? $reader]) {
    if (_$$loading) {
      throw StateError(
        'A default of AppEnv reads the global `env`. Use the getter directly: write `appEnv`, not `env.appEnv`.',
      );
    }
    _$$loading = true;
    try {
      EnvReader $r = $reader ?? EnvReader();
      String? appEnv = $r.string('APP_ENV');
      int? appPort = $r.integer('APP_PORT');
      String? appUrl = $r.string('APP_URL');
      String? region = $r.string('REGION');
      String? r = $r.string('R');
      String? reader = $r.string('READER');
      String? broken = $r.string('BROKEN');

      $r.check();
      _$AppEnv $env = _$AppEnv._(
        appEnv: appEnv,
        appPort: appPort,
        appUrl: appUrl,
        region: region,
        r: r,
        reader: reader,
        broken: broken,
      );
      $env.appEnv;
      $env.appPort;
      $env.appUrl;
      $env.region;
      $env.broken;

      return $env;
    } finally {
      _$$loading = false;
    }
  }
}
