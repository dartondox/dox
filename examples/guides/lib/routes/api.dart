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
    Route.post('/upload', uploadController.store);

    // pagination
    Route.get('/users', userController.index);
    Route.get('/users/{id}', userController.show);
    Route.delete('/users/{id}', userController.destroy);

    // jwt auth
    Route.post('/auth/register', authController.register);
    Route.post('/auth/login', authController.login);
    Route.middleware(<dynamic>[AuthMiddleware()], () {
      Route.get('/auth/me', authController.me);
      Route.post('/auth/logout', authController.logout);
    });

    // background work
    Route.post('/reports', reportController.store);
    Route.get('/primes/{limit}', reportController.primes);

    // custom errors: remove after the check
    Route.get('/boom', (DoxRequest req) => throw StateError('boom'));
  }
}
