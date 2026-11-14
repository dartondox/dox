// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_env.dart';

// **************************************************************************
// Generator: DoxEnvBuilder
// **************************************************************************

class _$AppEnv extends AppEnv {
  _$AppEnv._({
    required String? appEnv,
    required bool? isDevelopment,
    required String? region,
    required String? broken,
  }) : _$appEnv = appEnv,
       _$isDevelopment = isDevelopment,
       _$region = region,
       _$broken = broken;

  final String? _$appEnv;
  @override
  late final String appEnv = _$appEnv ?? super.appEnv;
  final bool? _$isDevelopment;
  @override
  late final bool isDevelopment = _$isDevelopment ?? super.isDevelopment;
  final String? _$region;
  @override
  late final String? region = _$region ?? super.region;
  final String? _$broken;
  @override
  late final String broken = _$broken ?? super.broken;

  /// reads and checks every key once. Throws `EnvException` with all
  /// missing or bad keys. Then works out every default once, so a default
  /// that throws stops the app here, at startup.
  static AppEnv load([EnvReader? reader]) {
    EnvReader r = reader ?? EnvReader();
    String? appEnv = r.string('APP_ENV');
    bool? isDevelopment = r.boolean('IS_DEVELOPMENT');
    String? region = r.string('REGION');
    String? broken = r.string('BROKEN');

    r.check();
    _$AppEnv $env = _$AppEnv._(
      appEnv: appEnv,
      isDevelopment: isDevelopment,
      region: region,
      broken: broken,
    );
    $env.appEnv;
    $env.isDevelopment;
    $env.region;
    $env.broken;

    return $env;
  }
}
