import 'package:dox_query_builder/dox_query_builder.dart';
import 'package:dox_query_builder/src/drivers/mysql_driver.dart';
import 'package:mysql1/mysql1.dart';
import 'package:postgres/postgres.dart';

class SqlQueryBuilder {
  static final SqlQueryBuilder _singleton = SqlQueryBuilder._internal();

  factory SqlQueryBuilder() {
    return _singleton;
  }

  SqlQueryBuilder._internal();

  late DBDriver dbDriver;

  bool debug = true;

  QueryPrinter printer = PrettyQueryPrinter();

  /// initialize query builder
  /// ```
  ///  SqlQueryBuilder.initialize(
  ///   database: db,
  ///   debug: true,
  ///   prettyPrint: true
  /// );
  /// ```
  static void initialize({
    required dynamic database,
    bool debug = false,
    QueryPrinter? printer,
    Driver driver = Driver.postgres,
  }) {
    SqlQueryBuilder sql = SqlQueryBuilder();

    if (driver == Driver.postgres) {
      if (database is! Connection) {
        throw Exception(
            'Invalid database connection. It must be postgres `Connection` type');
      }
      sql.dbDriver = PostgresDriver(conn: database);
    } else if (driver == Driver.mysql) {
      if (database is! MySqlConnection) {
        throw Exception(
            'Invalid database connection. It must be `MySqlConnection` type');
      }
      sql.dbDriver = MysqlDriver(conn: database);
    } else {
      throw Exception('Invalid driver or not supported');
    }

    sql.debug = debug;
    // coverage:ignore-start
    if (printer != null) {
      sql.printer = printer;
    }
    // coverage:ignore-end
  }
}
