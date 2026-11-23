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

Call each scope as a method on the query, without the query argument:

```dart
List<User> adults = await User().isActive().olderThan(18).get();
```

The scope name must not be the name of a field, a method of the model or a query method. So name a scope `isActive`, not `active`, next to an `active` field.

## Global scopes

A **global scope** adds a condition to every query of the model. Use `@Scope(global: true)`:

```dart
@DoxModel()
class Post extends PostGenerator {
  @Scope(global: true)
  static QueryBuilder<Post> notArchived(QueryBuilder<Post> q) {
    return q.where('archived', false);
  }
}

await Post().get(); // ... WHERE ("archived" = false)
```

It applies to reads, counts, query updates and deletes, and relation queries. So `Post().delete()` deletes only the rows in the scope.

### Removing global scopes

Remove one scope by its method name, or remove all of them:

```dart
await Post().withoutGlobalScope('notArchived').get();
await Post().withoutGlobalScopes().find(1);
```

A query write with `withoutGlobalScopes()` and no `where` throws a `StateError`.

## Next steps

- [Query Builder](../query-builder.md): the methods you can use in a scope.
- [Model](index.md): the model basics.
