import 'dart:async';
import 'dart:isolate';

import 'package:dox_core/dox_core.dart';
import 'package:my_app/app/jobs/build_report.job.dart';

@Inject()
class ReportController {
  /// POST /api/reports
  /// Answers at once. The work runs after the response, in this isolate.
  Map<String, String> store(DoxRequest req) {
    String id = DateTime.now().microsecondsSinceEpoch.toString();
    unawaited(_build(id));
    return <String, String>{'id': id, 'status': 'queued'};
  }

  /// POST /api/reports/queued
  /// Saves a job in the jobs table and answers at once.
  /// The queue worker (`dox queue:work`) runs it, and tries again when
  /// it fails. The job is not lost when the server stops.
  Future<Map<String, String>> queue(DoxRequest req) async {
    String id = DateTime.now().microsecondsSinceEpoch.toString();
    String jobId = await BuildReport(reportId: id).dispatch();
    return <String, String>{'id': id, 'job': jobId, 'status': 'queued'};
  }

  /// I/O work (database, HTTP calls, email) is fine here. It shares the
  /// event loop with the requests, so it must not block the CPU.
  Future<void> _build(String id) async {
    await Future<void>.delayed(const Duration(seconds: 2));
    print('report $id is ready');
  }

  /// GET /api/primes/{limit}
  /// CPU work runs on another thread with `Isolate.run`.
  /// The request waits for the result, but other requests are not blocked.
  Future<Map<String, int>> primes(int limit) async {
    int count = await Isolate.run(() => countPrimes(limit));
    return <String, int>{'limit': limit, 'primes': count};
  }
}

/// Must be a top level or static function with plain arguments.
/// The new isolate has no Dox, no database and no providers.
int countPrimes(int limit) {
  List<bool> sieve = List<bool>.filled(limit + 1, true);
  int count = 0;
  for (int i = 2; i <= limit; i++) {
    if (!sieve[i]) continue;
    count++;
    for (int j = i * i; j <= limit; j += i) {
      sieve[j] = false;
    }
  }
  return count;
}
