import 'package:dox_core/dox_core.dart';
import 'package:dox_orm/dox_orm.dart' hide Schema;

part 'database.dto.g.dart';

@Dto()
class CreateMember {
  @Email()
  @Unique('members', column: 'email')
  final String email;

  @Exists('teams')
  final int teamId;

  @Exists('tags')
  final List<int> tagIds;

  const CreateMember({
    required this.email,
    required this.teamId,
    this.tagIds = const <int>[],
  });

  static const DtoSchema<CreateMember> schema = $CreateMemberDto;
}

@Dto()
class UpdateMember {
  @Unique('members', column: 'email', ignoreParam: 'id')
  final String email;

  const UpdateMember({required this.email});

  static const DtoSchema<UpdateMember> schema = $UpdateMemberDto;
}
