// Stress test: finds requests that never finish (a stall or a deadlock).
//
// Many isolates send many queries at once: single queries, bursts of 20,
// transactions, new SQL text (statement cache churn) and errors. A killer
// ends random connections with pg_terminate_backend. Every request that
// takes over 2 s is a hang. Errors are fine, hangs are not.
//
//   dart run tool/stress.dart [seconds] [isolates] [workers per isolate]
//
// DB_HOST / DB_PORT pick the Postgres server (user and password postgres).
import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:dox_postgres_native/dox_postgres_native.dart';

String host = Platform.environment['DB_HOST'] ?? 'localhost';
int port = int.parse(Platform.environment['DB_PORT'] ?? '5432');

PgNativePool open() => PgNativePool.open(
  host: host,
  port: port,
  user: 'postgres',
  password: 'postgres',
  database: 'postgres',
  maxConnections: 4,
  applicationName: 'stress',
  threads: int.parse(Platform.environment['THREADS'] ?? '1'),
);

const String _badValue = "SELECT '294276-12-31'::timestamp";

Future<void> main(List<String> args) async {
  int seconds = args.isNotEmpty ? int.parse(args[0]) : 60;
  int isolates = args.length > 1 ? int.parse(args[1]) : 4;
  int workers = args.length > 2 ? int.parse(args[2]) : 64;

  PgNativePool setup = open();
  await setup.query('DROP TABLE IF EXISTS stress_world');
  await setup.query(
    'CREATE TABLE stress_world (id int PRIMARY KEY, n int NOT NULL)',
  );
  await setup.query(
    'INSERT INTO stress_world SELECT i, i FROM generate_series(1, 10000) i',
  );

  ReceivePort reports = ReceivePort();
  SendPort to = reports.sendPort;
  List<Future<Object?>> done = <Future<Object?>>[];
  for (int i = 0; i < isolates; i++) {
    // half the isolates share the pool of the main isolate
    int? shared = i.isEven ? setup.handle : null;
    done.add(Isolate.run(() => _isolate(i, shared, seconds, workers, to)));
  }
  int hangs = 0;
  reports.listen((Object? m) {
    stdout.writeln(m);
    if ('$m'.startsWith('HANG')) hangs++;
  });

  // the killer: ends one random connection of the test every 300 ms
  Random rnd = Random();
  int kills = 0;
  Stopwatch clock = Stopwatch()..start();
  while (clock.elapsed.inSeconds < seconds) {
    await Future<void>.delayed(Duration(milliseconds: 100 + rnd.nextInt(400)));
    try {
      await setup
          .query('''
          SELECT pg_terminate_backend(pid) FROM pg_stat_activity
          WHERE application_name = 'stress' AND pid <> pg_backend_pid()
          ORDER BY random() LIMIT 1''')
          .timeout(const Duration(seconds: 2));
      kills++;
    } catch (_) {
      // the killer itself can be killed
    }
  }
  List<int> totals = <int>[0, 0];
  for (Object? r in await Future.wait(done)) {
    List<int> t = r as List<int>;
    totals[0] += t[0];
    totals[1] += t[1];
  }
  await Future<void>.delayed(const Duration(milliseconds: 100));
  reports.close();
  stdout.writeln(
    'done: ${totals[0]} requests, ${totals[1]} errors, $kills kills, '
    '$hangs hangs',
  );
  exit(hangs == 0 ? 0 : 1);
}

Future<List<int>> _isolate(
  int index,
  int? shared,
  int seconds,
  int workers,
  SendPort report,
) async {
  PgNativePool pool = shared != null ? PgNativePool.fromHandle(shared) : open();
  Random rnd = Random(index);
  int requests = 0;
  int errors = 0;
  DateTime end = DateTime.now().add(Duration(seconds: seconds));

  /// runs one request and reports it when it takes over 2 s
  Future<T> watch<T>(String what, Future<T> Function() run) async {
    requests++;
    Stopwatch s = Stopwatch()..start();
    bool late = false;
    Timer t = Timer(const Duration(seconds: 2), () {
      late = true;
      report.send('HANG isolate $index: $what (over 2 s)');
    });
    try {
      return await run();
    } finally {
      t.cancel();
      if (late) {
        report.send('  late finish isolate $index: $what after ${s.elapsed}');
      }
    }
  }

  Future<void> find() => watch(
    'find',
    () => pool.query(
      'SELECT id, n FROM stress_world WHERE id = @id',
      parameters: <String, dynamic>{'id': 1 + rnd.nextInt(10000)},
    ),
  );

  Future<void> one() async {
    switch (rnd.nextInt(20)) {
      case < 10:
        await find();
      case < 15:
        for (int i = 0; i < 20; i++) {
          await find();
        }
      case < 17:
        int tx = await watch('begin', pool.begin);
        try {
          for (int i = 0; i < 3; i++) {
            await watch(
              'tx query',
              () => pool.query(
                'UPDATE stress_world SET n = n + 1 WHERE id = @id',
                parameters: <String, dynamic>{'id': 1 + rnd.nextInt(10000)},
                transaction: tx,
              ),
            );
          }
          await watch('commit', () => pool.commit(tx));
        } catch (_) {
          await watch('rollback', () => pool.rollback(tx));
          rethrow;
        }
      case < 19:
        // new SQL text: statement cache churn
        int k = rnd.nextInt(2000);
        await watch(
          'churn',
          () => pool.query('SELECT $k + \$1::int AS v', parameters: <int>[k]),
        );
      case < 20 when rnd.nextBool():
        await watch('error', () => pool.query('SELECT * FROM nope_missing'));
      default:
        // a value Dart can not decode, and requests after the end
        Future<void> bad = watch<Object?>(
          'bad value',
          () => pool.query(_badValue),
        ).then((_) {}, onError: (Object _) {});
        int tx = await watch('begin', pool.begin);
        await Future.wait(
          <Future<void>>[
            watch('rollback', () => pool.rollback(tx)),
            watch('2nd rollback', () => pool.rollback(tx)),
            watch('late query', () => pool.query('SELECT 1', transaction: tx)),
          ].map((Future<Object?> f) => f.catchError((Object _) => null)),
        );
        await bad;
    }
  }

  Future<void> worker() async {
    while (DateTime.now().isBefore(end)) {
      try {
        await one();
      } catch (_) {
        errors++;
      }
    }
  }

  await Future.wait(<Future<void>>[for (int i = 0; i < workers; i++) worker()]);
  if (shared == null) pool.close();
  return <int>[requests, errors];
}
