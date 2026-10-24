import 'package:dox_postgres_native/dox_postgres_native.dart';
import 'package:test/test.dart';

// No database needed: a pool connects on its first query.
PgNativePool open(int max) => PgNativePool.open(
  host: '127.0.0.1',
  port: 1,
  user: 'u',
  database: 'share_test',
  maxConnections: max,
);

void main() {
  test('the same settings share one pool until the last close', () {
    PgNativePool a = open(3);
    PgNativePool b = open(3);
    PgNativePool other = open(4);
    expect(b.handle, a.handle);
    expect(other.handle, isNot(a.handle));
    a.close();
    // still open for b: the same settings give the same pool again
    PgNativePool again = open(3);
    expect(again.handle, a.handle);
    again.close();
    for (PgNativePool p in <PgNativePool>[b, a, other]) {
      p.close();
    }
    PgNativePool fresh = open(3);
    expect(fresh.handle, isNot(a.handle));
    fresh.close();
  });

  test('a closed pool refuses new work, the shared pool stays open', () async {
    PgNativePool a = open(5);
    PgNativePool b = open(5);
    a.close();
    a.close(); // a second close does nothing
    await expectLater(a.query('SELECT 1'), throwsStateError);
    await expectLater(a.begin(), throwsStateError);
    PgNativePool c = open(5);
    expect(c.handle, b.handle);
    c.close();
    b.close();
  });
}
