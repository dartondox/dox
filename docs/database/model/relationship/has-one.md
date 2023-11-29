# HasOne

A one-to-one relationship represents a fundamental type of database association. As an example, consider a `User` model linked to a `UserInfo` model. To establish this connection, we define a method called `userInfo` within the `User` model. This `userInfo` method invokes the `HasOne` method and returns its output.

=== "HasOne Class Structure"

    ```dart
    class HasOne {
        final Type model;
        final String? foreignKey;
        final String? localKey;
        final Function? onQuery;
        final bool? eager;

        const HasOne(this.model,
            {this.foreignKey, this.localKey, this.onQuery, this.eager});
    }
    ```

#####
=== "User Model"

    ```dart
    @DoxModel()
    class User extends UserGenerator {
        @Column()
        String? name;

        @HasOne(UserInfo)
        UserInfo? userInfo;
    }
    ```

=== "UserInfo Model"

    ```dart
    @DoxModel()
    class UserInfo extends UserInfoGenerator {
        @Column()
        String? userId;

        @Column()
        String? address;

        @Column(name: 'house_number')
        String? houseNumber;
    }
    ```

## Usage

#### `$getRelation`

```dart
User? user = await User().find(1);
await user?.$getRelation('userInfo')

UserInfo userInfo = user?.userInfo;
```
!!! info
    When `eager` is `true` the `$getRelation` do not need to call.

#### `preload`

```dart
User? user = await User().preload('userInfo').find(1);
UserInfo userInfo = user?.userInfo;
```
!!! info
    When `eager` is `true` the `preload` do not need to call.

#### `related`

```dart
User? user = await User().find(1);
UserInfo userInfo = await user?.related<UserInfo>('userInfo')?.where('foo', 'bar').getFirst();
```

## Options

#### `model`

```dart
@HasOne(UserInfo)
UserInfo? userInfo;
```
#### `foreignKey`

```dart
@HasOne(UserInfo, foreignKey: 'user_id')
UserInfo? userInfo;
```

#### `localKey`

```dart
@HasOne(UserInfo, foreignKey: 'user_id', localKey: 'id')
UserInfo? userInfo;
```

#### `onQuery`

```dart
@DoxModel()
class User extends UserGenerator {
    @HasOne(UserInfo, onQuery: onUserInfoQuery)
    UserInfo? userInfo;

    static QueryBuilder<UserInfo> onUserInfoQuery(UserInfo q) {
        return q.where('status', 'active');
    }
}
```
!!! info
    `onQuery` method must be a static method inside the model.

#### `eager`

```dart
@HasOne(UserInfo, eager: true)
UserInfo? userInfo;
```

