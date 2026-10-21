// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'env.dart';

// **************************************************************************
// Generator: DoxEnvBuilder
// **************************************************************************

class _$AppEnv extends AppEnv {
  _$AppEnv._({
    required this.appName,
    required this.appEnv,
    required this.appKey,
    required this.appPort,
    required this.appTotalIsolate,
    required this.appUrl,
    required this.logLevel,
    required this.cacheStore,
    required this.storageDisk,
    required this.socketioEnabled,
    required this.dbConnection,
    required this.dbHost,
    required this.dbPort,
    required this.dbUsername,
    required this.dbPassword,
    required this.dbName,
    required this.redisHost,
    required this.redisPort,
    required this.redisDb,
    required this.redisUsername,
    required this.redisPassword,
    required this.awsBucket,
    required this.awsDefaultRegion,
    required this.awsAccessKeyId,
    required this.awsSecretAccessKey,
    required this.awsEndpoint,
  });

  @override
  final String appName;
  @override
  final String appEnv;
  @override
  final String appKey;
  @override
  final int appPort;
  @override
  final int appTotalIsolate;
  @override
  final String appUrl;
  @override
  final String logLevel;
  @override
  final String cacheStore;
  @override
  final String storageDisk;
  @override
  final bool socketioEnabled;
  @override
  final String dbConnection;
  @override
  final String dbHost;
  @override
  final int? dbPort;
  @override
  final String? dbUsername;
  @override
  final String? dbPassword;
  @override
  final String? dbName;
  @override
  final String redisHost;
  @override
  final int redisPort;
  @override
  final int redisDb;
  @override
  final String? redisUsername;
  @override
  final String? redisPassword;
  @override
  final String? awsBucket;
  @override
  final String awsDefaultRegion;
  @override
  final String awsAccessKeyId;
  @override
  final String awsSecretAccessKey;
  @override
  final String? awsEndpoint;

  /// reads and checks every key once. Throws `EnvException` with all
  /// missing or bad keys.
  static AppEnv load([EnvReader? reader]) {
    EnvReader r = reader ?? EnvReader();
    _$AppEnvDefaults d = _$AppEnvDefaults();
    String appName = r.string('APP_NAME') ?? d.appName;
    String appEnv = r.string('APP_ENV') ?? d.appEnv;
    String appKey = r.string('APP_KEY') ?? d.appKey;
    int appPort = r.integer('APP_PORT') ?? d.appPort;
    int appTotalIsolate = r.integer('APP_TOTAL_ISOLATE') ?? d.appTotalIsolate;
    String appUrl = r.string('APP_URL') ?? d.appUrl;
    String logLevel = r.string('LOG_LEVEL') ?? d.logLevel;
    String cacheStore = r.string('CACHE_STORE') ?? d.cacheStore;
    String storageDisk = r.string('STORAGE_DISK') ?? d.storageDisk;
    bool socketioEnabled = r.boolean('SOCKETIO_ENABLED') ?? d.socketioEnabled;
    String dbConnection = r.string('DB_CONNECTION') ?? d.dbConnection;
    String dbHost = r.string('DB_HOST') ?? d.dbHost;
    int? dbPort = r.integer('DB_PORT');
    String? dbUsername = r.string('DB_USERNAME');
    String? dbPassword = r.string('DB_PASSWORD');
    String? dbName = r.string('DB_NAME');
    String redisHost = r.string('REDIS_HOST') ?? d.redisHost;
    int redisPort = r.integer('REDIS_PORT') ?? d.redisPort;
    int redisDb = r.integer('REDIS_DB') ?? d.redisDb;
    String? redisUsername = r.string('REDIS_USERNAME');
    String? redisPassword = r.string('REDIS_PASSWORD');
    String? awsBucket = r.string('AWS_BUCKET');
    String awsDefaultRegion =
        r.string('AWS_DEFAULT_REGION') ?? d.awsDefaultRegion;
    String awsAccessKeyId = r.string('AWS_ACCESS_KEY_ID') ?? d.awsAccessKeyId;
    String awsSecretAccessKey =
        r.string('AWS_SECRET_ACCESS_KEY') ?? d.awsSecretAccessKey;
    String? awsEndpoint = r.string('AWS_ENDPOINT');

    r.check();
    return _$AppEnv._(
      appName: appName,
      appEnv: appEnv,
      appKey: appKey,
      appPort: appPort,
      appTotalIsolate: appTotalIsolate,
      appUrl: appUrl,
      logLevel: logLevel,
      cacheStore: cacheStore,
      storageDisk: storageDisk,
      socketioEnabled: socketioEnabled,
      dbConnection: dbConnection,
      dbHost: dbHost,
      dbPort: dbPort,
      dbUsername: dbUsername,
      dbPassword: dbPassword,
      dbName: dbName,
      redisHost: redisHost,
      redisPort: redisPort,
      redisDb: redisDb,
      redisUsername: redisUsername,
      redisPassword: redisPassword,
      awsBucket: awsBucket,
      awsDefaultRegion: awsDefaultRegion,
      awsAccessKeyId: awsAccessKeyId,
      awsSecretAccessKey: awsSecretAccessKey,
      awsEndpoint: awsEndpoint,
    );
  }
}

/// gives the getter bodies of [AppEnv] (the defaults)
class _$AppEnvDefaults extends AppEnv {
  @override
  int? get dbPort => throw StateError('DB_PORT has no default');
  @override
  String? get dbUsername => throw StateError('DB_USERNAME has no default');
  @override
  String? get dbPassword => throw StateError('DB_PASSWORD has no default');
  @override
  String? get dbName => throw StateError('DB_NAME has no default');
  @override
  String? get redisUsername =>
      throw StateError('REDIS_USERNAME has no default');
  @override
  String? get redisPassword =>
      throw StateError('REDIS_PASSWORD has no default');
  @override
  String? get awsBucket => throw StateError('AWS_BUCKET has no default');
  @override
  String? get awsEndpoint => throw StateError('AWS_ENDPOINT has no default');
}
