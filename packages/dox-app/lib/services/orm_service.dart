import 'package:dox_app/config/postgres.dart';
import 'package:dox_core/dox_core.dart';
import 'package:dox_query_builder/dox_query_builder.dart';
import 'package:postgres/postgres.dart';

/// Query builder service
/// --------------------------
/// Initializing to setup query builder so that this project can use ORM.
/// If this project do not require database, you can simply delete this file
/// and remove from config/services.dart list.
class ORMService implements DoxService {
  @override
  Future<void> setup() async {
    /// Initialize Sql QueryBuilder
    SqlQueryBuilder.initialize(
      database: await Connection.open(
        postgresEndpoint,
        settings: postgresPoolSetting,
      ),
      debug: true,
      printer: Env.get('APP_ENV') == 'development'
          ? PrettyQueryPrinter()
          : ConsoleQueryPrinter(),
    );
  }
}
