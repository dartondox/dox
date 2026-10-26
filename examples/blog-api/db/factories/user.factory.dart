import 'package:dox_orm/factory.dart';
import 'package:blog/app/models/user/user.model.dart';

class UserFactory extends Factory<User> {
  @override
  User definition() {
    User user = User();
    user.name = 'Jane';
    user.password = 'secret';
    return user;
  }
}
