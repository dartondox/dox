import 'package:dox_query_builder/dox_query_builder.dart';
import 'package:postgres/postgres.dart';

class SqlQueryBuilder {
  static final SqlQueryBuilder _singleton = SqlQueryBuilder._internal();

  factory SqlQueryBuilder() {
    return _singleton;
  }

  SqlQueryBuilder._internal();

  late DBDriver db;

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
    required Connection database,
    bool debug = false,
    QueryPrinter? printer,
  }) {
    SqlQueryBuilder sql = SqlQueryBuilder();
    sql.db = PostgresDriver(conn: database);
    sql.debug = debug;
    // coverage:ignore-start
    if (printer != null) {
      sql.printer = printer;
    }
    // coverage:ignore-end
  }
}
