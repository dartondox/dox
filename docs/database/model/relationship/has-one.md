---
icon: lucide/link
---

# HasOne

Use `HasOne` when one row of this table has one row in another table.

For example, a user has one user info row. The other table keeps the foreign key (`user_info.user_id`).

## Defining the relation

Add a field with `@HasOne(...)` to the model. The field type is the related model, and it is nullable:

```dart title="lib/app/models/user/user.model.dart"
import 'package:dox_orm/dox_orm.dart';

import '../user_info/user_info.model.dart';

part 'user.model.g.dart';

@DoxModel()
class User extends UserGenerator {
  @Column()
  String? name;

  @HasOne(UserInfo)
  UserInfo? userInfo;
}
```

The related model has the foreign key column:

```dart title="lib/app/models/user_info/user_info.model.dart"
import 'package:dox_orm/dox_orm.dart';

part 'user_info.model.g.dart';

@DoxModel()
class UserInfo extends UserInfoGenerator {
  @Column()
  int? userId; // column user_id

  @Column()
  String? address;
}
```

Run `dart run build_runner build` after you add a relationship.

### Custom keys

By default the foreign key is the class name in snake_case and `_id`, so `User` gives `user_id`. This is also true when the table is `users`. If your columns have other names, set `foreignKey` and `localKey`:

```dart
@HasOne(UserInfo, foreignKey: 'owner_id', localKey: 'id')
UserInfo? userInfo;
```

## Loading the relation

The relation is not loaded by default. Use the field name (`'userInfo'`) as the relation name.

### Preloading

Use `preload` when you load the models with a query. For a list of users, it runs one query for all of them:

```dart
User? user = await User().preload('userInfo').find(1);
print(user?.userInfo?.address);
```

`preload` works with `find`, `get`, `all` and `getFirst`.

### Loading on a model you have

If you already have the model, use `$getRelation`:

```dart
User? user = await User().find(1);
await user?.$getRelation('userInfo');
print(user?.userInfo?.address);
```

### Querying the relation

Sometimes you need more conditions on the related row. `related` gives you a query for it. It does not set `user.userInfo`:

```dart
User? user = await User().find(1);
UserInfo? info = await user
    ?.related<UserInfo>('userInfo')
    ?.where('address', '!=', '')
    .getFirst();
```

### Always loading the relation

If every query of `User` should load the relation, set `eager: true`. Then you do not call `preload`:

```dart
@HasOne(UserInfo, eager: true)
UserInfo? userInfo;
```

## Filtering by the relation

`whereHas()` keeps the users that have a `user_info` row. `whereDoesntHave()` keeps the users without one. They do not load the `UserInfo`:

```dart
List<User> users = await User().whereHas('userInfo').get();

List<User> inParis = await User().whereHas('userInfo', (QueryBuilder<dynamic> q) {
  q.where('address', 'Paris');
}).get();

List<User> noInfo = await User().whereDoesntHave('userInfo').get();
```

See [Query by relations](../relation-queries.md).

## Changing the relation query

Sometimes the relation should only load some rows. Give `onQuery` a static function in the same model class. It gets the query of the related model and returns it:

```dart
@DoxModel()
class User extends UserGenerator {
  @HasOne(UserInfo, onQuery: onlyActive)
  UserInfo? userInfo;

  static QueryBuilder<UserInfo> onlyActive(UserInfo q) {
    return q.where('status', 'active');
  }
}
```

## Details

### All options

| Option | Default | What it is |
|---|---|---|
| `foreignKey` | `{this model}_id`, like `user_id` | The column in the related table that points to this model. |
| `localKey` | the primary key of this model | The column in this table that `foreignKey` points to. |
| `onQuery` | none | A static function that changes the query. |
| `eager` | `false` | Load the relation on every query. |

### Other cases

- A relation with `eager: true` is always in `toJson()`. A relation loaded with `preload` is in `toJson()` of that query. The JSON key is the field name in snake_case: `user_info`.
- `reload()` and a preload set the relation fields again, also when there is no related row. See [Relationships](../index.md#relationships).
- The load runs one query like this:

```sql
SELECT *, "user_id" as "_owner_id" FROM "user_info" WHERE "user_id" IN (@user_id_p0)
```
