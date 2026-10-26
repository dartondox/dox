import 'package:dox_core/dox_core.dart';
import 'package:dox_queue/dox_queue.dart';

/// Builds a report in the queue worker.
/// Dispatch it: `await BuildReport(reportId: id).dispatch();`
@Job()
class BuildReport extends DoxJob {
  BuildReport({required this.reportId});

  final String reportId;

  /// try 3 times, wait 10 seconds between tries
  @override
  int get tries => 3;

  @override
  List<Duration> get backoff => const <Duration>[Duration(seconds: 10)];

  @override
  Future<void> handle() async {
    Logger.info('report $reportId is ready');
  }
}
