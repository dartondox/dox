import 'package:dox_orm/dox_orm.dart';

part 'user.model.g.dart';

@DoxModel(table: 'users', softDelete: true)
class User extends UserGenerator {
  @override
  List<String> get hidden => <String>['password'];

  @override
  List<String> get fillable => <String>['name', 'email', 'password'];

  @Column()
  String? name;

  @Column()
  String? email;

  @Column()
  String? password;
}
