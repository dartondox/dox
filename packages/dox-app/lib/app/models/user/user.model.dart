import 'package:dox_orm/dox_orm.dart';

part 'user.model.g.dart';

@DoxModel(softDelete: true, table: 'users')
class User extends UserGenerator {
  @override
  List<String> get hidden => <String>['password'];

  @Column()
  String? name;

  @Column()
  String? email;

  @Column()
  String? password;
}
