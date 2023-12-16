import 'package:dox_core/dox_core.dart';

import '../../../app/models/user/user.model.dart';

class UserSerializer extends Serializer<User> {
  UserSerializer(super.data);

  @override
  Map<String, dynamic> convert(User m) {
    return <String, dynamic>{};
  }
}
