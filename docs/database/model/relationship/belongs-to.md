# BelongsTo

A "belongs-to" relationship is a fundamental concept in database modeling. Consider a scenario where we have a `Comment` model associated with a `User` model. In this case, we define a method called `user` within the `Comment` model. This `user` method invokes the `BelongsTo` method and returns its output. This relationship signifies that a comment belongs to a particular user.

In practical terms, this means that each comment in our database is linked to a single user. When we want to retrieve the user associated with a specific comment, we can use the `user` method, making it easy to access user information for that comment. This `BelongsTo` relationship helps establish connections between records in a meaningful way, enhancing the organization and retrieval of data in our database system.

=== "BelongsTo Class Structure"

    ```dart
    class BelongsTo {
        final Type model;
        final String? foreignKey;
        final String? localKey;
        final Function? onQuery;
        final bool? eager;

        const BelongsTo(this.model,
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

        @Column()
        String? status;
    }
    ```

=== "Comment Model"

    ```dart
    @DoxModel()
    class Comment extends CommentGenerator {
        @Column()
        String? userId;

        @Column()
        String? content;

        @BelongsTo(User)
        User? user;
    }
    ```

## Usage

#### `$getRelation`

```dart
List<Comment> comments = await Comment().all();

for (Comment comment in comments) {
    await comment.$getRelation('user')
    User user = comment.user;
}
```
!!! info
    When `eager` is `true` the `$getRelation` do not need to call.

#### `preload`

```dart
List<Comment> comments = await Comment().preload('user').all();
for (Comment comment in comments) {
    User user = comment.user;
}
```
!!! info
    When `eager` is `true` the `preload` do not need to call.

#### `related`

```dart
List<Comment> comments = await Comment().all();

for (Comment comment in comments) {
    User user = await comment.related<User>('user')?.where('foo', 'bar').getFirst();
}
```

## Options

#### `model`

```dart
@BelongsTo(User)
User? user;
```
#### `foreignKey`

```dart
@BelongsTo(User, foreignKey: 'user_id')
User? user;
```

#### `localKey`

```dart
@BelongsTo(User, foreignKey: 'user_id', localKey: 'id')
User? user;
```

#### `onQuery`

```dart
@DoxModel()
class Comment extends CommentGenerator {
    @Column()
    String? userId;

    @Column()
    String? content;

    @BelongsTo(User, onQuery: onQueryActiveUser)
    User? activeUser;

    static QueryBuilder<User> onQueryActiveUser(User q) {
        return q.where('status', 'active');
    }
}
```

!!! info
    `onQuery` method must be a static method inside the model.

#### `eager`

```dart
@BelongsTo(User, eager: true)
User? user;
```

