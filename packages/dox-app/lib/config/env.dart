import 'dart:io';

import 'package:dox_core/dox_core.dart';

part 'env.g.dart';

/// The env of the app, typed.
/// -------------------------------
/// Each getter reads one key: `appName` reads `APP_NAME`.
/// `@EnvKey('X')` picks another key. A getter body is the default.
/// A nullable getter with no body is optional. Any other getter with no
/// body is required: the app stops at startup when it is missing.
///
/// A real environment variable wins over the `.env` file.
/// Run `dart run build_runner build` after you change this class.
@DoxEnv()
abstract class AppEnv {
  /// reads and checks every key once. Throws `EnvException` with all
  /// missing or bad keys.
  static AppEnv load([EnvReader? reader]) {
    return _$AppEnv.load(reader);
  }

  String get appName => 'dox';

  /// development, local or production
  String get appEnv => 'development';

  /// Encrypts cookies and cache. Startup stops when it is empty and
  /// APP_ENV is production. Make one with `dox key:generate`.
  String get appKey => '';

  int get appPort => 3000;

  /// isolates that serve http requests. Default is one per CPU core.
  int get appTotalIsolate => Platform.numberOfProcessors;

  String get appUrl => 'http://localhost:3000';

  String get logLevel => 'info';

  /// file, memory, redis or null
  String get cacheStore => 'file';

  /// local, or s3 when AWS_BUCKET is set
  String get storageDisk => 'local';

  bool get socketioEnabled => false;

  /// postgres, mysql or sqlite
  String get dbConnection => 'postgres';
  String get dbHost => 'localhost';

  /// empty means the default port of the driver
  int? get dbPort;
  String? get dbUsername;
  String? get dbPassword;
  String? get dbName;

  String get redisHost => '127.0.0.1';
  int get redisPort => 6379;
  int get redisDb => 0;
  String? get redisUsername;
  String? get redisPassword;

  String? get awsBucket;
  String get awsDefaultRegion => 'us-east-1';
  String get awsAccessKeyId => '';
  String get awsSecretAccessKey => '';
  String? get awsEndpoint;
}

/// The env of the app. Read and checked once, on first use.
final AppEnv env = AppEnv.load();
