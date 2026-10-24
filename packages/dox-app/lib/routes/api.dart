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
    ApiController api = ApiController();
    BlogController blogController = BlogController();
    AuthController authController = AuthController();

    Route.get('ping', <dynamic>[api.pong]);

    // Anyone can read blogs. Only a logged in user can change them.
    Route.get('blogs', blogController.index);
    Route.get('blogs/{id}', blogController.show);
    Route.middleware(<dynamic>[AuthMiddleware()], () {
      Route.post('blogs', blogController.store);
      Route.put('blogs/{id}', blogController.update);
      Route.patch('blogs/{id}', blogController.update);
      Route.delete('blogs/{id}', blogController.destroy);
    });

    Route.post('/auth/login', authController.login);
    Route.post('/auth/register', authController.register);
    Route.get('/auth/user', <dynamic>[AuthMiddleware(), authController.user]);
  }
}
