---
icon: lucide/filter
---

# Query scopes

A scope is a query part that you use again and again, like "only active users", written once in the model and called like a query method.

## Local scopes

Add a static method with `@Scope()` to the model. It takes the query first and returns the query. Then run `dart run build_runner build`:

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

The generator adds each scope as a method on the query of the model, so you can chain it with other query methods:

```dart
List<User> users = await User().isActive().get();

List<User> adults = await User()
    .where('name', 'like', 'a%')
    .isActive()
    .olderThan(18)
    .get();
```

A scope can take more arguments: required, optional (`[...]`) and named (`{...}`). The generated method takes the same arguments, without the query.

The scope name must not be a field or a method of the model. For example, a scope `active` next to a field `active` does not work, so name it `isActive`. A scope named like a query method (`count`, `get`) is never called.

## Global scopes

Sometimes every query of a model needs the same condition, like "leave out archived posts". Use `@Scope(global: true)` for this:

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

The scope is added to every query: `get()`, `find()`, `all()`, `count()`, `paginate()`, query updates and deletes, and relation queries. The scope goes in brackets, so an `orWhere()` in your query can not skip it.

A global scope counts as a `where`, so `Post().delete()` deletes only the rows in the scope.

### Removing global scopes

If one query needs the rows outside the scope, remove the scope by its method name with `withoutGlobalScope()`. To remove all of them, use `withoutGlobalScopes()`:

```dart
await Post().withoutGlobalScope('notArchived').get();
await Post().withoutGlobalScopes().find(1);
```

## Details

- `save()`, `delete()` and `restore()` on a model object work on that one row. They do not use the global scopes.
- A query write with `withoutGlobalScopes()` and no `where` throws a `StateError`.
- Soft deletes are not a global scope. Use `withTrash()` for them.

## See also

- [Query Builder](../query-builder.md): the methods you can use in a scope.
- [Model](index.md): the model basics.
