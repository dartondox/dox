import 'package:dox_query_builder/dox_query_builder.dart';
import 'package:dox_query_builder/src/drivers/mysql_driver.dart';

enum Driver { postgres, mysql }

/// interface for database driver
abstract class DBDriver {
  Driver getName();

  /// run query and return map result
  Future<List<Map<String, dynamic>>> query(
    String query, {
    String? primaryKey,
    Map<String, dynamic>? substitutionValues,
  });

  /// run query, this function do not return any value
  Future<void> execute(String query,
      {Map<String, dynamic>? substitutionValues});
}

/// get database driver to run queries
DBDriver getDatabaseDriver(Driver driver, dynamic database) {
  /// checking validation for postgres connection
  if (driver == Driver.postgres) {
    return PostgresDriver(conn: database);
  }

  /// checking validation for mysql connection
  else if (driver == Driver.mysql) {
    return MysqlDriver(conn: database);
  }
  throw Exception('Invalid driver or not supported');
}
