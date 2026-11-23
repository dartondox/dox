---
icon: lucide/book-open-text
---

# Pagination

Make a list route that takes `page` and `per_page` from the query string and returns one page of rows.

A table can have many thousands of rows, so the client asks for one page at a time.

## What you need

- A Dox app (`dox create my_app`). A new app has a database (SQLite), a `User` model and a `users` table.

## 1. Write the query DTO

The [DTO](../the-basic/dto.md) reads and checks `page` and `per_page`. With `source: Source.query`, it reads the query string, not the body:

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

Both fields have a default, so the client can leave them out. The field `perPage` reads the key `per_page`.

## 2. Write the controller

`paginate()` returns a `Pagination`. Return it as it is, and Dox sends its `toJson()`:

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

Always add an `orderBy`. Without it, a row can show on two pages, or on none. To filter the rows, add a `where` before `paginate`.

## 3. Add the route

Add the list route to the API router:

```dart title="lib/routes/api.dart"
Route.get('/users', (UserController c) => c.index);
```

## 4. Register the DTOs

Add the `dtos` list that `build_runner` writes. Skip this step if your `app.dart` already has `dtos: dtos`:

```dart title="lib/config/app.dart"
import 'package:my_app/generated/dtos.g.dart';

AppConfig appConfig = AppConfig(
  dtos: dtos,
  // ...
);
```

## 5. Build and run

Build the code and start the server:

```bash
dart run build_runner build --delete-conflicting-outputs
dox serve
```

## Check it

Ask for page 2, with 2 rows per page. With 3 users in the table, you get one user:

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
    {
      "id": 1,
      "name": "User 1",
      "email": "user1@example.com",
      "created_at": "2026-10-22T14:01:07.843207Z",
      "updated_at": "2026-10-22T14:01:07.843207Z"
    }
  ]
}
```

The keys of the response are:

| Key | Meaning |
| --- | --- |
| `total` | rows that match the query, on all pages |
| `per_page` | rows per page |
| `last_page` | the number of the last page |
| `current_page` | the page you asked for |
| `data` | the rows of this page, from `toJson()` of the model |

A page after the last one gives an empty list in `data`.

Bad input gets 422:

```bash
curl 'http://localhost:3000/api/users?page=0&per_page=500'
```

```json
{
  "page": "The page must be greater than or equal 1",
  "per_page": "The per_page must be between 1 and 100"
}
```

## Change the shape of a row

To send only some fields, pass the rows to a serializer. Make one with `dox make:serializer User`. `page.data` gives the typed rows:

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

## Next steps

- [Query builder: paginate](../database/query-builder.md#paginating-results): all the paginate options.
- [DTOs: body and query string](../the-basic/dto.md#body-and-query-string): read the query string.
- [Serializer](../the-basic/serializer.md): change the shape of a model.
