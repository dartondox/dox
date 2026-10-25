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
    Route.get('/ping', (ApiController c) => c.pong);

    // Anyone can read posts.
    Route.get('/posts', (PostController c) => c.index);
    Route.get('/posts/{id}', (PostController c) => c.show);

    // Register and log in.
    Route.post('/auth/register', (AuthController c) => c.register);
    Route.post('/auth/login', (AuthController c) => c.login);

    // Only a logged in user can write posts.
    Route.middleware(<dynamic>[AuthMiddleware()], () {
      Route.get('/auth/user', (AuthController c) => c.user);
      Route.post('/posts', (PostController c) => c.store);
      Route.put('/posts/{id}', (PostController c) => c.update);
    });
  }
}
