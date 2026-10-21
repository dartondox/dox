/// Marks a typed env class. `dox_builder` writes `_$<Class>` for it.
///
/// ```dart
/// part 'env.g.dart';
///
/// @DoxEnv()
/// abstract class AppEnv {
///   static AppEnv load([EnvReader? reader]) {
///     return _$AppEnv.load(reader);
///   }
///
///   String get appName; // APP_NAME, required
///   int get appPort => 3000; // APP_PORT, default 3000
///   @EnvKey('AWS_BUCKET')
///   String? get s3Bucket; // optional
/// }
/// ```
class DoxEnv {
  const DoxEnv();
}

/// Reads a getter from this env key, not from the UPPER_SNAKE getter name.
class EnvKey {
  final String name;

  const EnvKey(this.name);
}
