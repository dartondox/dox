import 'package:dox_app/app/http/controllers/api.controller.dart';
import 'package:dox_app/app/http/controllers/auth.controller.dart';
import 'package:dox_app/app/http/controllers/blog.controller.dart';
import 'package:dox_auth/dox_auth.dart';
import 'package:dox_core/dox_core.dart';

class ApiRouter extends Router {
  @override
  String get prefix => 'api';

  @override
  List<dynamic> get middleware => <dynamic>[];

  @override
  void register() {
    Route.get<ApiController>('ping', (ApiController c) => c.pong);

    // Anyone can read blogs. Only a logged in user can change them.
    Route.get<BlogController>('blogs', (BlogController c) => c.index);
    Route.get<BlogController>('blogs/{id}', (BlogController c) => c.show);
    Route.middleware(<dynamic>[AuthMiddleware()], () {
      Route.post<BlogController>('blogs', (BlogController c) => c.store);
      Route.put<BlogController>('blogs/{id}', (BlogController c) => c.update);
      Route.patch<BlogController>('blogs/{id}', (BlogController c) => c.update);
      Route.delete<BlogController>(
        'blogs/{id}',
        (BlogController c) => c.destroy,
      );
    });

    Route.post<AuthController>('/auth/login', (AuthController c) => c.login);
    Route.post<AuthController>(
      '/auth/register',
      (AuthController c) => c.register,
    );
    Route.get<AuthController>('/auth/user', <dynamic>[
      AuthMiddleware(),
      (AuthController c) => c.user,
    ]);
  }
}
