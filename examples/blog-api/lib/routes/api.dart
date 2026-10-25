import 'package:blog/app/http/controllers/api.controller.dart';
import 'package:blog/app/http/controllers/auth.controller.dart';
import 'package:blog/app/http/controllers/post.controller.dart';
import 'package:dox_auth/dox_auth.dart';
import 'package:dox_core/dox_core.dart';

class ApiRouter extends Router {
  @override
  String get prefix => 'api';

  @override
  List<dynamic> get middleware => <dynamic>[];

  @override
  void register() {
    Route.get<ApiController>('/ping', (ApiController c) => c.pong);

    // Anyone can read posts.
    Route.get<PostController>('/posts', (PostController c) => c.index);
    Route.get<PostController>('/posts/{id}', (PostController c) => c.show);

    // Register and log in.
    Route.post<AuthController>(
      '/auth/register',
      (AuthController c) => c.register,
    );
    Route.post<AuthController>('/auth/login', (AuthController c) => c.login);

    // Only a logged in user can write posts.
    Route.middleware(<dynamic>[AuthMiddleware()], () {
      Route.get<AuthController>('/auth/user', (AuthController c) => c.user);
      Route.post<PostController>('/posts', (PostController c) => c.store);
      Route.put<PostController>('/posts/{id}', (PostController c) => c.update);
    });
  }
}
