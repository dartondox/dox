import 'package:blog/config/database.dart';
import 'package:dox_core/dox_core.dart';
import 'package:dox_orm/dox_orm.dart';

/// Query builder service
/// --------------------------
/// Sets up the query builder, so this project can use the ORM.
/// If this project does not need a database, delete this file
/// and remove it from config/services.dart.
class ORMService implements DoxService, DoxShutdown {
  @override
  Future<void> setup() async {
    SqlQueryBuilder.initializeWithDatabaseConfig(databaseConfig);
  }

  /// Close the database connections when the server stops.
  @override
  Future<void> shutdown() async {
    await SqlQueryBuilder.close();
  }
}
