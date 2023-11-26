import 'package:dox_query_builder/dox_query_builder.dart';

part 'user.model.g.dart';

@DoxModel(
  table: 'users',
  createdAt: 'created_at',
  updatedAt: 'updated_at',
  softDelete: true,
)
class User extends UserGenerator {
  @Column()
  String? name;
}
