---
icon: lucide/book-open-text
---

# Pagination

Make a list route that takes `page` and `per_page` from the query string and returns one page of rows.

A table can have many thousands of rows. You do not want to send them all in one response, because it is slow for the server and for the client. So the client asks for one page at a time.

## What you need

- A Dox app (`dox create my_app`). A new app has a database (SQLite), a `User` model and a `users` table.

## 1. Write the query DTO

The [DTO](../the-basic/dto.md) reads `page` and `per_page` and checks them. Because it has `source: Source.query`, it reads the query string, not the body. The field `perPage` reads the key `per_page`, because keys are snake_case by default.

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

Both fields have a default, so the client can leave them out. `@Range(1, 100)` stops a client from asking for 10000 rows at once.

## 2. Write the controller

`paginate()` runs one `count` query and one `select` query, and returns a `Pagination`. The controller can return it as it is, because Dox sends its `toJson()`.

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

You should always add an `orderBy`. Without it, the database may return the rows in a different order on each page, so a row can show up twice or not at all.

If you want to filter the rows, add a `where` before `paginate`: `User().where('role', 'admin').orderBy('id').paginate(...)`.

## 3. Add the route

```dart title="lib/routes/api.dart"
Route.get('/users', (UserController c) => c.index);
```

## 4. Register the DTOs

Dox finds a DTO in the `dtos` list of `AppConfig`. `build_runner` writes this list to `lib/generated/dtos.g.dart`. You add it only once, so skip this step if your `app.dart` already has `dtos: dtos`.

```dart title="lib/config/app.dart"
import 'package:my_app/generated/dtos.g.dart';

AppConfig appConfig = AppConfig(
  dtos: dtos,
  // ...
);
```

## 5. Build and run

```bash
dart run build_runner build --delete-conflicting-outputs
dox serve
```

## Check it

Ask for page 2, with 2 rows per page. With 3 users in the table, you get the last user:

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

The keys of the answer are:

| Key | Meaning |
| --- | --- |
| `total` | rows that match the query, on all pages |
| `per_page` | rows per page |
| `last_page` | the number of the last page |
| `current_page` | the page you asked for |
| `data` | the rows of this page, from `toJson()` of the model |

If you ask for a page after the last one, `data` is an empty list.

Bad input gets `422` before the controller runs:

```bash
curl 'http://localhost:3000/api/users?page=0&per_page=500'
```

```json
{"page":"The page must be greater than or equal 1","per_page":"The per_page must be between 1 and 100"}
```

## Change the shape of a row

Sometimes the model has fields you do not want to send. Then use a serializer for the rows. `dox make:serializer User` makes `lib/app/serializers/user.serializer.dart`. `page.data` gives the typed rows (`List<User>`), so you can pass them to the serializer:

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

- [Query builder: paginate](../database/query-builder.md#paginating-results)
- [DTOs: body and query string](../the-basic/dto.md#body-and-query-string)
- [Serializer](../the-basic/serializer.md)
