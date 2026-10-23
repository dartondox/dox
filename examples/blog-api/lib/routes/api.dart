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
    Route.get('/ping', apiController.pong);

    // Anyone can read posts.
    Route.get('/posts', postController.index);
    Route.get('/posts/{id}', postController.show);

    // Register and log in.
    Route.post('/auth/register', authController.register);
    Route.post('/auth/login', authController.login);

    // Only a logged in user can write posts.
    Route.middleware(<dynamic>[AuthMiddleware()], () {
      Route.get('/auth/user', authController.user);
      Route.post('/posts', postController.store);
      Route.put('/posts/{id}', postController.update);
    });
  }
}
