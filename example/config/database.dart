import 'package:dox_core/dox_core.dart';
import 'package:dox_migration/dox_migration.dart';
import 'package:dox_query_builder/dox_query_builder.dart';
import 'package:postgres_pool/postgres_pool.dart';

class Database implements DoxService {
  /// Declare as Singleton to reuse connection pool
  static final Database _i = Database._internal();
  factory Database() => _i;
  Database._internal();

  late PgPool pool;

  late PgEndpoint endPoint;

  bool debug = false;

  int concurrency = 10;

  @override
  Future<void> setup() async {
    Database().endPoint = PgEndpoint(
      host: Env.get('DB_HOST', 'localhost'),
      port: int.parse(Env.get('DB_PORT', '5432')),
      database: Env.get('DB_NAME', 'dox'),
      username: Env.get('DB_USERNAME', 'postgres'),
      password: Env.get('DB_PASSWORD', 'postgres'),
    );

    Database().pool = PgPool(
      Database().endPoint,
      settings: PgPoolSettings()
        ..maxConnectionAge = Duration(hours: 1)
        ..concurrency = concurrency,
    );

    /// this will create connection pool initially when server started
    /// so prevent connecting to connection pool when calling API for first time
    await Database().pool.query('SELECT 1');

    /// Initialize Sql QueryBuilder
    SqlQueryBuilder.initialize(
      database: Database().pool,
      debug: debug,
      printer: ConsoleQueryPrinter(),
    );
  }

  Future<void> migrate() async {
    await Migration().migrate();
  }
}
