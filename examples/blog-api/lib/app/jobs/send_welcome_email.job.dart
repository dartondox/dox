import 'package:dox_core/utils/logger.dart';
import 'package:dox_queue/dox_queue.dart';

/// Sends the welcome email of a new user.
/// Dispatch it: `await SendWelcomeEmail(userId: user.id).dispatch();`
@Job()
class SendWelcomeEmail extends DoxJob {
  SendWelcomeEmail({required this.userId});

  final int userId;

  @override
  int get tries => 3;

  @override
  List<Duration> get backoff => const <Duration>[Duration(seconds: 10)];

  @override
  Future<void> handle() async {
    Logger.info('Send a welcome email to user $userId');
  }
}
