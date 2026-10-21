import 'package:dox_orm/dox_orm.dart';

part 'user.model.g.dart';

@DoxModel(
  table: 'users',
  softDelete: true,
)
class User extends UserGenerator {
  @Column()
  String? name;
}
