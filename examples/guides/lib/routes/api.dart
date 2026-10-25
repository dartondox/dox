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
    Route.post<UploadController>('/upload', (UploadController c) => c.store);

    // pagination
    Route.get<UserController>('/users', (UserController c) => c.index);
    Route.get<UserController>('/users/{id}', (UserController c) => c.show);
    Route.delete<UserController>(
      '/users/{id}',
      (UserController c) => c.destroy,
    );

    // jwt auth
    Route.post<AuthController>(
      '/auth/register',
      (AuthController c) => c.register,
    );
    Route.post<AuthController>('/auth/login', (AuthController c) => c.login);
    Route.middleware(<dynamic>[AuthMiddleware()], () {
      Route.get<AuthController>('/auth/me', (AuthController c) => c.me);
      Route.post<AuthController>(
        '/auth/logout',
        (AuthController c) => c.logout,
      );
    });

    // background work
    Route.post<ReportController>('/reports', (ReportController c) => c.store);
    Route.get<ReportController>(
      '/primes/{limit}',
      (ReportController c) => c.primes,
    );

    // custom errors: remove after the check
    Route.get('/boom', (DoxRequest req) => throw StateError('boom'));
  }
}
