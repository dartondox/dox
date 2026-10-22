# HasOne

Use `HasOne` when one row of this table has one row in another table.
For example, a user has one user info row.
The other table keeps the foreign key (`user_info.user_id`).

## Define it

Add a field with `@HasOne(...)` to the model. The field type is the related model, nullable.

=== "User"

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

=== "UserInfo"

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

## Load it

The relation is not loaded by default. Load it in one of these ways.
Use the field name (`'userInfo'`) as the relation name.

=== "preload"

    ```dart
    User? user = await User().preload('userInfo').find(1);
    print(user?.userInfo?.address);
    ```

    `preload` works with `find`, `get`, `all` and `getFirst`.
    For a list of users, it runs one query for all of them.

=== "$getRelation"

    ```dart
    User? user = await User().find(1);
    await user?.$getRelation('userInfo');
    print(user?.userInfo?.address);
    ```

    Use it when you already have the model.

=== "related"

    ```dart
    User? user = await User().find(1);
    UserInfo? info = await user
        ?.related<UserInfo>('userInfo')
        ?.where('address', '!=', '')
        .getFirst();
    ```

    `related` gives a query. You can add more conditions before you run it.
    It does not set `user.userInfo`.

=== "eager"

    ```dart
    @HasOne(UserInfo, eager: true)
    UserInfo? userInfo;
    ```

    With `eager: true`, every query of `User` loads the relation.
    You do not call `preload`.

The load runs this SQL:

```sql
SELECT *, "user_id" as "_owner_id" FROM "user_info" WHERE "user_id" IN (@user_id_p0)
```

## Options

| Option | Default | What it is |
|---|---|---|
| `foreignKey` | `{this table}_id`, like `user_id` | The column in the related table that points to this model. |
| `localKey` | the primary key of this model | The column in this table that `foreignKey` points to. |
| `onQuery` | none | A static function that changes the query. |
| `eager` | `false` | Load the relation on every query. |

!!! warning "Custom table names"
    The default `foreignKey` uses the table name, not the class name.
    With `@DoxModel(table: 'users')`, the default is `users_id`.
    Then set `foreignKey: 'user_id'` yourself.

### `foreignKey` and `localKey`

```dart
@HasOne(UserInfo, foreignKey: 'owner_id', localKey: 'id')
UserInfo? userInfo;
```

### `onQuery`

`onQuery` is a static function in the same model class.
It gets the query of the related model and returns it.

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

## In JSON

- A relation with `eager: true` is always in `toJson()`.
- A relation loaded with `preload` is in `toJson()` of that query.
- The JSON key is the field name in snake_case: `user_info`.

!!! warning "Known issue: names with more than one word"
    For a relation without `eager: true`, `toJson()` looks for the snake_case name in the preload list.
    But `preload` needs the field name (`'userInfo'`).
    So a preloaded `userInfo` is on the model, but it is not in `toJson()`.
    Use a one word field name (like `info`), or `eager: true`, when you need it in JSON.
