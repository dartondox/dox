import 'package:dox_core/dox_core.dart';
import 'package:dox_orm/dox_orm.dart';
import 'package:my_app/config/database.dart';

/// Query builder provider
/// --------------------------
/// Sets up the query builder, so this project can use the ORM.
/// If this project does not need a database, delete this file
/// (Dox finds every DoxProvider class, see lib/generated/container.g.dart).
class ORMProvider extends DoxProvider {
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
