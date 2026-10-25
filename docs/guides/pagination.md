---
icon: lucide/book-open-text
---

# Pagination

Make a list route that takes `page` and `per_page` from the query string and returns one page of rows.

## What you need

- A Dox app with a database and a `User` model (`dox make:model User -m`).
- `build_runner` for the DTO.

## 1. Write the query DTO

A DTO with `source: Source.query` reads the query string, also for `POST`.
The query key of `perPage` is `per_page`, because keys are snake_case by default.

```dart title="lib/app/dtos/list_users/list_users.dto.dart"
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
```

Both fields have a default, so both are optional. `@Range(1, 100)` stops a client from asking for 10000 rows.

## 2. Write the controller

`paginate()` runs one `count` query and one `select` query. It returns a `Pagination`.
A controller can return it as it is. Dox sends `toJson()`.

```dart title="lib/app/http/controllers/user.controller.dart"
import 'package:dox_core/dox_core.dart';
import 'package:dox_orm/dox_orm.dart';
import 'package:my_app/app/dtos/list_users/list_users.dto.dart';
import 'package:my_app/app/models/user/user.model.dart';

@Inject()
class UserController {
  /// GET /api/users?page=1&per_page=20
  Future<Pagination<User>> index(ListUsers query) async {
    return User()
        .orderBy('id', 'desc')
        .paginate(currentPage: query.page, perPage: query.perPage);
  }
}
```

Always add an `orderBy`. Without it, the database may return the rows in a different order on each page.

Add a `where` before `paginate` to filter: `User().where('role', 'admin').orderBy('id').paginate(...)`.

## 3. Add the route

```dart title="lib/routes/api.dart"
Route.get('/users', (UserController c) => c.index);
```

## 4. Build and run

```bash
dart run build_runner build --delete-conflicting-outputs
dox serve
```

## Check it

With 3 users in the table:

```bash
curl 'http://localhost:3000/api/users?page=2&per_page=2'
```

```json
{
  "total": 3,
  "per_page": 2,
  "last_page": 2,
  "current_page": 2,
  "data": [
    {"id": 1, "name": "User 1", "email": "user1@example.com", "created_at": "2026-10-22T14:01:07.843207Z", "updated_at": "2026-10-22T14:01:07.843207Z"}
  ]
}
```

| Key | Meaning |
| --- | --- |
| `total` | rows that match the query, on all pages |
| `per_page` | rows per page |
| `last_page` | the number of the last page |
| `current_page` | the page you asked for |
| `data` | the rows of this page, from `toJson()` of the model |

A page after the last one gives an empty `data` list.

Bad input gets `422` before the controller runs:

```bash
curl 'http://localhost:3000/api/users?page=0&per_page=500'
```

```json
{"page":"The page must be greater than or equal 1","per_page":"The per_page must be between 1 and 100"}
```

## Change the shape of a row

Return a serializer for each row, when the model has fields you do not want to send.
`page.data` gives the typed rows (`List<User>`):

```dart
Future<Map<String, dynamic>> index(ListUsers query) async {
  Pagination<User> page = await User()
      .orderBy('id', 'desc')
      .paginate(currentPage: query.page, perPage: query.perPage);
  return <String, dynamic>{
    ...page.toJson(),
    'data': UserSerializer(page.data).toJson(),
  };
}
```

## See also

- [Query builder: paginate](../database/query-builder.md#paginate)
- [Validation: where the data comes from](../the-basic/validation.md#where-the-data-comes-from)
- [Serializer](../the-basic/serializer.md)
