import 'package:dox_auth/dox_auth.dart';
import 'package:dox_core/dox_core.dart';
import 'package:my_app/app/http/controllers/auth.controller.dart';
import 'package:my_app/app/http/controllers/report.controller.dart';
import 'package:my_app/app/http/controllers/upload.controller.dart';
import 'package:my_app/app/http/controllers/user.controller.dart';

class ApiRouter extends Router {
  @override
  String get prefix => 'api';

  @override
  List<dynamic> get middleware => <dynamic>[];

  @override
  void register() {
    Route.get('/ping', (DoxRequest req) => 'pong');

    // file upload
    Route.post('/upload', (UploadController c) => c.store);

    // pagination
    Route.get('/users', (UserController c) => c.index);
    Route.get('/users/{id}', (UserController c) => c.show);
    Route.delete('/users/{id}', (UserController c) => c.destroy);

    // jwt auth
    Route.post('/auth/register', (AuthController c) => c.register);
    Route.post('/auth/login', (AuthController c) => c.login);
    Route.middleware(<dynamic>[AuthMiddleware()], () {
      Route.get('/auth/me', (AuthController c) => c.me);
      Route.post('/auth/logout', (AuthController c) => c.logout);
    });

    // background work
    Route.post('/reports', (ReportController c) => c.store);
    Route.post('/reports/queued', (ReportController c) => c.queue);
    Route.get('/primes/{limit}', (ReportController c) => c.primes);

    // custom errors: remove after the check
    Route.get('/boom', (DoxRequest req) => throw StateError('boom'));
  }
}
