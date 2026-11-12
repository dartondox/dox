import 'package:dox_cache_database/dox_cache_database.dart';
import 'package:dox_orm/dox_orm.dart';
import 'package:test/test.dart';

/// A driver that fails the first [failures] writes with [error].
class FailingDriver extends DBDriver {
  FailingDriver(this.error, {this.failures = 1000, this.open = false});

  final Object error;
  final int failures;

  /// what [hasOpenTransaction] gives
  final bool open;

  int writes = 0;

  @override
  Driver getName() => Driver.mysql;

  @override
  bool get hasOpenTransaction => open;

  @override
  Future<List<Map<String, dynamic>>> query(
    String query, {
    String? primaryKey,
    Map<String, dynamic>? substitutionValues,
  }) async {
    return <Map<String, dynamic>>[];
  }

  @override
  Future<void> execute(
    String query, {
    Map<String, dynamic>? substitutionValues,
  }) async {
    await affectingStatement(query);
  }

  @override
  Future<int> affectingStatement(
    String query, {
    Map<String, dynamic>? substitutionValues,
  }) async {
    writes++;
    if (writes <= failures) throw error;
    return 1;
  }

  @override
  Future<R> transaction<R>(Future<R> Function() callback) => callback();
}

MysqlException deadlock() => MysqlException('deadlock', code: 1213);

void main() {
  test('a deadlock runs the write again', () async {
    FailingDriver db = FailingDriver(deadlock(), failures: 2);
    expect(await DatabaseCacheDriver(database: db).forget('a'), isTrue);
    expect(db.writes, 3);
  });

  test('after 5 runs the deadlock goes to the caller', () async {
    FailingDriver db = FailingDriver(deadlock());
    await expectLater(
      DatabaseCacheDriver(database: db).put('a', 1, null),
      throwsA(isA<MysqlException>()),
    );
    expect(db.writes, DatabaseCacheDriver.deadlockTries);
  });

  test('a Postgres deadlock runs again too', () async {
    FailingDriver db = FailingDriver(
      PgServerException('deadlock', code: '40P01', severity: 'ERROR'),
      failures: 1,
    );
    expect(await DatabaseCacheDriver(database: db).forget('a'), isTrue);
    expect(db.writes, 2);
  });

  test('a lock wait timeout is not retried', () async {
    FailingDriver db = FailingDriver(
      MysqlException('lock wait timeout', code: 1205, sqlState: 'HY000'),
    );
    await expectLater(
      DatabaseCacheDriver(database: db).forget('a'),
      throwsA(isA<MysqlException>()),
    );
    expect(db.writes, 1);
  });

  test('inside an app transaction a deadlock is not retried', () async {
    FailingDriver db = FailingDriver(deadlock(), open: true);
    await expectLater(
      DatabaseCacheDriver(database: db).forget('a'),
      throwsA(isA<MysqlException>()),
    );
    expect(db.writes, 1);
  });

  test('isDeadlock', () {
    expect(DatabaseCacheDriver.isDeadlock(deadlock()), isTrue);
    expect(
      DatabaseCacheDriver.isDeadlock(
        PgServerException('x', code: '40001', severity: 'ERROR'),
      ),
      isTrue,
    );
    expect(
      DatabaseCacheDriver.isDeadlock(MysqlException('x', code: 1062)),
      isFalse,
    );
    expect(DatabaseCacheDriver.isDeadlock(StateError('x')), isFalse);
  });
}
