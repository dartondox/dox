# Query scopes

A scope is a query part that you use again and again, like "only active users".
You write it once in the model. Then you call it like a query method.

## Local scopes

Add a static method with `@Scope()` to the model.
It takes the query first and returns the query.
Then run `dart run build_runner build`.

```dart
@DoxModel()
class User extends UserGenerator {
  @Column()
  bool? active;

  @Column()
  int? age;

  @Scope()
  static QueryBuilder<User> isActive(QueryBuilder<User> q) {
    return q.where('active', true);
  }

  @Scope()
  static QueryBuilder<User> olderThan(QueryBuilder<User> q, int age) {
    return q.where('age', '>', age);
  }
}
```

The generator adds each scope as a method on the query of the model:

```dart
List<User> users = await User().isActive().get();

List<User> adults = await User()
    .where('name', 'like', 'a%')
    .isActive()
    .olderThan(18)
    .get();
```

A scope can take more arguments: required, optional (`[...]`) and named (`{...}`).
The generated method takes the same arguments, without the query.

!!! warning "Pick a free name"
    The scope name must not be a field or a method of the model.
    For example, a scope `active` next to a field `active` does not work.
    Use `isActive`. A scope named like a query method (`count`, `get`) is never called.

## Global scopes

`@Scope(global: true)` adds the scope to every query of the model.
This includes `get()`, `find()`, `all()`, `count()`, `paginate()`,
query updates and deletes, and relation queries.

```dart
@DoxModel()
class Post extends PostGenerator {
  @Column()
  bool? archived;

  /// every query leaves out archived posts
  @Scope(global: true)
  static QueryBuilder<Post> notArchived(QueryBuilder<Post> q) {
    return q.where('archived', false);
  }
}

await Post().get(); // ... WHERE ("archived" = false)
```

The global scope goes in brackets, and your own conditions too.
So an `orWhere()` in your query can not skip the scope.

Remove a global scope for one query with `withoutGlobalScope()`,
or remove all of them with `withoutGlobalScopes()`:

```dart
await Post().withoutGlobalScope('notArchived').get();
await Post().withoutGlobalScopes().find(1);
```

The name of a global scope is the method name.

!!! info
    `save()`, `delete()` and `restore()` on a model instance work on that one row.
    They do not use the global scopes.
    Soft deletes are not a global scope. Use `withTrash()` for them.
