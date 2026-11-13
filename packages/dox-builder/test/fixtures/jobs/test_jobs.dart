import 'dart:async';

import 'package:dox_queue/dox_queue.dart';

/// what the test jobs did, read by the tests
class JobLog {
  static List<String> handled = <String>[];
  static List<String> failed = <String>[];
  static Map<String, int> runs = <String, int>{};

  /// SlowJob runs now, and the most at once
  static int running = 0;
  static int mostRunning = 0;

  static void clear() {
    handled.clear();
    failed.clear();
    runs.clear();
    running = 0;
    mostRunning = 0;
  }
}

enum Color { red, green }

@Job()
class SendWelcomeEmail extends DoxJob {
  SendWelcomeEmail({required this.userId});

  final int userId;

  @override
  Future<void> handle() async {
    JobLog.handled.add('welcome $userId');
  }
}

/// every type the builder can save
@Job(name: 'all-types')
class AllTypesJob extends DoxJob {
  AllTypesJob(
    this.count,
    this.price,
    this.amount,
    this.title,
    this.active,
    this.at,
    this.color, {
    this.note,
    this.tags = const <String>[],
    this.scores = const <String, double>{},
    this.dates = const <DateTime?>[],
    this.nested = const <List<int>>[],
    this.colors = const <String, Color>{},
    this.extra,
    this.maybeAt,
    this.maybeColor,
  });

  final int count;
  final double price;
  final num amount;
  final String title;
  final bool active;
  final DateTime at;
  final Color color;
  final String? note;
  final List<String> tags;
  final Map<String, double> scores;
  final List<DateTime?> dates;
  final List<List<int>> nested;
  final Map<String, Color> colors;
  final Map<String, dynamic>? extra;
  final DateTime? maybeAt;
  final Color? maybeColor;

  @override
  Future<void> handle() async {}
}

/// fails [failTimes] times, then works
@Job()
class FlakyJob extends DoxJob {
  FlakyJob({required this.key, required this.failTimes, this.maxTries = 3});

  final String key;
  final int failTimes;
  final int maxTries;

  @override
  int get tries => maxTries;

  @override
  List<Duration> get backoff => const <Duration>[Duration(milliseconds: 150)];

  @override
  Future<void> handle() async {
    int run = (JobLog.runs[key] ?? 0) + 1;
    JobLog.runs[key] = run;
    if (run <= failTimes) throw StateError('flaky $key run $run');
    JobLog.handled.add('flaky $key');
  }

  @override
  void failed(Object error, StackTrace stack) {
    JobLog.failed.add('flaky $key: $error');
  }
}

/// waits [millis], then works
@Job()
class SlowJob extends DoxJob {
  SlowJob({required this.key, required this.millis, this.timeoutMillis});

  final String key;
  final int millis;
  final int? timeoutMillis;

  @override
  Duration? get timeout {
    int? value = timeoutMillis;
    return value == null ? null : Duration(milliseconds: value);
  }

  @override
  String get queue => 'slow';

  @override
  Future<void> handle() async {
    JobLog.running++;
    if (JobLog.running > JobLog.mostRunning) {
      JobLog.mostRunning = JobLog.running;
    }
    try {
      await Future<void>.delayed(Duration(milliseconds: millis));
    } finally {
      JobLog.running--;
    }
    JobLog.handled.add('slow $key');
  }

  @override
  void failed(Object error, StackTrace stack) {
    JobLog.failed.add('slow $key: ${error.runtimeType}');
  }
}
