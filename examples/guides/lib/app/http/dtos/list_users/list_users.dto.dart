import 'package:dox_core/dox_core.dart';

part 'list_users.dto.g.dart';

/// GET /api/users?page=2&per_page=10
@Dto(source: Source.query)
class ListUsers {
  @Min(1)
  final int page;

  @Range(1, 100)
  final int perPage; // query key: per_page

  const ListUsers({this.page = 1, this.perPage = 20});

  static const DtoSchema<ListUsers> schema = $ListUsersDto;
}
