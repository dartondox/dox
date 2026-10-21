import 'package:dox_orm/dox_orm.dart';

import 'db_connection.dart';

/// a dox_orm [DBDriver] on the migration connection, so `Schema` runs on
/// the same connection (and transaction) as the migrator.
class MigrationDriver extends DBDriver {
  /// the connection, or the open transaction while one runs
  DbConnection conn;

  bool _inTransaction = false;

  MigrationDriver(this.conn);

  @override
  Driver getName() {
    if (conn.isMysql) return Driver.mysql;
    if (conn.isSqlite) return Driver.sqlite;
    return Driver.postgres;
  }

  @override
  Future<List<Map<String, dynamic>>> query(
    String query, {
    String? primaryKey,
    Map<String, dynamic>? substitutionValues,
  }) {
    var (String sql, List<Object?> params) = toPositionalParams(
      query,
      substitutionValues,
      _same,
    );
    return conn.execute(sql, params);
  }

  @override
  Future<void> execute(
    String query, {
    Map<String, dynamic>? substitutionValues,
  }) async {
    await this.query(query, substitutionValues: substitutionValues);
  }

  /// ponytail: a nested transaction joins the open one (no savepoint)
  @override
  Future<R> transaction<R>(Future<R> Function() callback) async {
    if (_inTransaction) return await callback();
    DbConnection outer = conn;
    return await outer.transaction((DbConnection tx) async {
      conn = tx;
      _inTransaction = true;
      try {
        return await callback();
      } finally {
        conn = outer;
        _inTransaction = false;
      }
    });
  }

  static Object? _same(dynamic value) => value;
}
