import 'package:dox_core/dox_core.dart';
import 'package:dox_orm/dox_orm.dart';
import 'package:my_app/app/exceptions/app_exception.dart';
import 'package:my_app/app/http/dtos/list_users.dto.dart';
import 'package:my_app/app/models/user/user.model.dart';

@Inject()
class UserController {
  /// GET /api/users?page=1&per_page=20
  Future<Pagination<User>> index(ListUsers query) async {
    return User()
        .orderBy('id', 'desc')
        .paginate(currentPage: query.page, perPage: query.perPage);
  }

  /// GET /api/users/{id}
  Future<User> show(int id) async {
    User? user = await User().find(id);
    if (user == null) {
      throw NotFoundHttpException(message: 'User $id not found');
    }
    return user;
  }

  /// DELETE /api/users/{id}
  Future<Map<String, bool>> destroy(int id) async {
    if (id == 1) {
      throw ForbiddenException(message: 'The first user can not be deleted');
    }
    User user = await show(id);
    await user.delete();
    return <String, bool>{'deleted': true};
  }
}
