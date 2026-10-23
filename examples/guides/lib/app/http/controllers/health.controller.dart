import 'package:dox_core/dox_core.dart';
import 'package:dox_orm/dox_orm.dart';

class HealthController {
  /// GET /health. 200 when the app and the database answer.
  /// Any database error becomes a 500, so the health check fails.
  Future<Map<String, String>> check(DoxRequest req) async {
    await QueryBuilder.query('select 1');
    return <String, String>{'status': 'ok'};
  }
}

HealthController healthController = HealthController();
