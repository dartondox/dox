import 'package:dox_core/dox_core.dart';
import 'package:dox_migration/dox_migration.dart' as mi;
import 'package:dox_query_builder/dox_query_builder.dart';
import 'package:postgres_pool/postgres_pool.dart';

class DatabaseService implements DoxService {
  /// Declare as Singleton to use connection pool
  static final DatabaseService _i = DatabaseService._internal();
  factory DatabaseService() => _i;
  DatabaseService._internal();

  late PgPool pool;

  late PgEndpoint endPoint;

  bool debug = true;

  int concurrency = 10;

  @override
  Future<void> setup() async {
    endPoint = PgEndpoint(
      host: Env.get('DB_HOST', 'localhost'),
      port: int.parse(Env.get('DB_PORT', '5432')),
      database: Env.get('DB_NAME', 'dox'),
      username: Env.get('DB_USERNAME', 'postgres'),
      password: Env.get('DB_PASSWORD', 'postgres'),
    );

    pool = PgPool(
      endPoint,
      settings: PgPoolSettings()
        ..maxConnectionAge = Duration(hours: 1)
        ..concurrency = concurrency,
    );

    /// this will create connection pool initially when server started
    /// so prevent connecting to connection pool when calling API for first time
    await pool.query('SELECT 1');

    /// Initialize Sql QueryBuilder
    SqlQueryBuilder.initialize(
      database: pool,
      debug: debug,
    );
  }

  Future<void> migrate() async {
    await mi.Migration().migrate();
  }
}
