import 'package:dox_core/dox_core.dart';
import 'package:dox_orm/dox_orm.dart';
import 'package:my_app/config/database.dart';

/// Query builder service
/// --------------------------
/// Sets up the query builder, so this project can use the ORM.
/// If this project does not need a database, delete this file
/// and remove it from config/services.dart.
class ORMService implements DoxService {
  @override
  Future<void> setup() async {
    SqlQueryBuilder.initializeWithDatabaseConfig(databaseConfig);
  }
}
