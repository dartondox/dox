# HasMany

A "one-to-many" relationship is another essential type of database association. Let's illustrate this with an example where we have a `User` model associated with a `Post` model. To establish this connection, we define a method called `posts` within the `User` model. This `posts` method invokes the `HasMany` method and returns its output, representing that a user can have multiple posts in the database. This relationship allows us to easily retrieve all the posts associated with a specific user when needed.

=== "HasMany Class Structure"

    ```dart
    class HasMany {
        final Type model;
        final String? foreignKey;
        final String? localKey;
        final Function? onQuery;
        final bool? eager;

        const HasMany(this.model,
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

        @HasMany(Post)
        Post? posts;
    }
    ```

=== "Post Model"

    ```dart
    @DoxModel()
    class Post extends PostGenerator {
        @Column()
        String? userId;

        @Column()
        String? title;

        @Column(name: 'desc')
        String? description;

        @Column()
        String? status;
    }
    ```

## Usage

#### `$getRelation`

```dart
User? user = await User().find(1);
await user?.$getRelation('blogs')

List<Blog> blogs = user?.blogs;
```
!!! info
    When `eager` is `true` the `$getRelation` do not need to call.

#### `preload`

```dart
User? user = await User().preload('blogs').find(1);
List<Blog> blogs = user?.blogs;
```
!!! info
    When `eager` is `true` the `preload` do not need to call.

#### `related`

```dart
User? user = await User().find(1);
List<Blog> activeBlogs = await user?.related<Blog>('blog')?.where('status', 'active').get();
```

## Options

#### `model`

```dart
@HasMany(Post)
Post? posts;
```
#### `foreignKey`

```dart
@HasMany(Post, foreignKey: 'user_id')
Post? posts;
```

#### `localKey`

```dart
@HasMany(Post, foreignKey: 'user_id', localKey: 'id')
Post? posts;
```

#### `onQuery`

```dart
@DoxModel()
class User extends UserGenerator {
    @HasMany(Post)
    Post? posts;

    @HasMany(Post, onQuery: activePostQuery)
    Post? activePosts;

    static QueryBuilder<Post> activePostQuery(Post q) {
        return q.where('status', 'active');
    }
}
```

!!! info
    `onQuery` method must be a static method inside the model.

#### `eager`

```dart
@HasMany(Post, eager: true)
Post? posts;
```

