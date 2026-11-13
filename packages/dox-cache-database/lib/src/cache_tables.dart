import 'package:dox_orm/dox_orm.dart';

import 'database_cache_driver.dart';

/// Makes and drops the table of [DatabaseCacheDriver]. Use it in a
/// migration (`dox cache:table` writes one):
///
/// ```
/// await CacheTables.up(schema);
/// ```
class CacheTables {
  /// Make the cache table, named [table].
  static Future<void> up(
    Schema schema, {
    String table = DatabaseCacheDriver.defaultTable,
  }) async {
    await schema.create(table, _columns);
  }

  /// Drop the cache table, named [table].
  static Future<void> down(
    Schema schema, {
    String table = DatabaseCacheDriver.defaultTable,
  }) async {
    await schema.dropIfExists(table);
  }

  static void _columns(Table t) {
    // utf8mb4_bin: on MySQL the default collation sees `A` and `a` as the
    // same key, and the same lock owner. Postgres and SQLite ignore it.
    t.string('key').primary().collation('utf8mb4_bin');
    t.longText('value').collation('utf8mb4_bin');
    // unix time in milliseconds, null means it never expires
    t.bigInteger('expires_at').nullable();
  }
}
