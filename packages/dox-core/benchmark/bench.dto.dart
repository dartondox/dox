import 'package:dox_core/dox_core.dart';

part 'bench.dto.g.dart';

enum Role { admin, user }

/// 6 fields, used by the `POST /dto` benchmark route
@Dto()
class CreateMember {
  @Length(min: 3, max: 50)
  @Trim()
  final String name;

  @Email()
  final String email;

  @Min(18)
  final int age;

  final Role role;

  @MaxItems(5)
  final List<String> tags;

  final bool active;

  const CreateMember({
    required this.name,
    required this.email,
    required this.age,
    required this.role,
    this.tags = const <String>[],
    required this.active,
  });

  static const DtoSchema<CreateMember> schema = $CreateMemberDto;
}
