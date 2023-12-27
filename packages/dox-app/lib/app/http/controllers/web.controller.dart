import 'package:dox_app/config/redis.dart';
import 'package:dox_core/dox_core.dart';

class WebController {
  String pong(DoxRequest req) {
    return 'pong';
  }

  dynamic testRedis(DoxRequest req) async {
    await redis.set('dox', 'awesome');
    return await redis.get('dox');
  }
}
