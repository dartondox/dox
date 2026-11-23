---
icon: lucide/link
---

# HasOne

Use `HasOne` when one row of this table has one row in another table.

For example, a user has one user info row. The other table keeps the foreign key: `user_info.user_id`.

## Setup

Add a nullable field with `@HasOne()` to the model. The related model has the foreign key column:

```dart title="lib/app/models/user/user.model.dart"
@DoxModel()
class User extends UserGenerator {
  @HasOne(UserInfo)
  UserInfo? userInfo;
}

@DoxModel()
class UserInfo extends UserInfoGenerator {
  @Column()
  int? userId; // column user_id

  @Column()
  String? address;
}
```

Run `dart run build_runner build` after you add a relation.

### Options

Set the keys when your columns have other names:

```dart
@HasOne(UserInfo, foreignKey: 'owner_id', localKey: 'id')
UserInfo? userInfo;
```

| Option | Default | What it is |
|---|---|---|
| `foreignKey` | `{this model}_id`, like `user_id` | The column in the related table that points to this model. |
| `localKey` | the primary key of this model | The column in this table that `foreignKey` points to. |
| `onQuery` | none | A static function that changes the query. |
| `eager` | `false` | Load the relation on every query. |

The default foreign key comes from the class name, also when the table is `users`.

## Loading the relation

The relation is not loaded by default. Use the field name, `'userInfo'`, as the relation name.

### Preloading

`preload()` loads the relation for all models of a query, with one more query:

```dart
User? user = await User().preload('userInfo').find(1);
print(user?.userInfo?.address);
```

The relation is then in `toJson()`, with the field name in snake_case as the key.

### Loading on a model you have

`$getRelation()` loads the relation into the field:

```dart
await user.$getRelation('userInfo');
```

### Querying the relation

`related()` gives a query for the related row. It does not set the field:

```dart
UserInfo? info = await user
    .related<UserInfo>('userInfo')
    ?.where('address', '!=', '')
    .getFirst();
```

### Always loading the relation

Set `eager: true` to load the relation on every query of the model:

```dart
@HasOne(UserInfo, eager: true)
UserInfo? userInfo;
```

## Saving related models

`createRelated()` and `saveRelated()` save the related model and set its foreign key:

```dart
await user.createRelated<UserInfo>('userInfo',
    <String, dynamic>{'address': 'Paris'});
await user.saveRelated('userInfo', UserInfo()..address = 'Paris');
```

Save the user first, because a model with no key throws a `StateError`.

## Filtering by the relation

`whereHas()` keeps the users that have a user info row. `whereDoesntHave()` keeps the users without one:

```dart
List<User> inParis = await User().whereHas('userInfo',
    (QueryBuilder<dynamic> q) {
  q.where('address', 'Paris');
}).get();

List<User> noInfo = await User().whereDoesntHave('userInfo').get();
```

See [Query by relations](../relation-queries.md).

## Changing the relation query

Give `onQuery` a static function of the model. It gets the query of the related model and returns it:

```dart
@HasOne(UserInfo, onQuery: byId)
UserInfo? userInfo;

static QueryBuilder<UserInfo> byId(UserInfo q) {
  return q.orderBy('id');
}
```

When there are many related rows, the relation keeps the last row of the query. So this example keeps the row with the highest id.

## Next steps

- [HasMany](has-many.md): one row with many related rows.
- [BelongsTo](belongs-to.md): the other side of the relation.
- [Counting relations](../counting-relations.md): count the related rows.
