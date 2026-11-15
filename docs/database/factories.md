---
icon: lucide/factory
---

# Factories

A factory makes models with sample data, so you can fill the database quickly in tests and [seeders](seeders.md).

## Defining factories

Use the `make:factory` command to make a factory:

```bash
dox make:factory User
```

This makes `db/factories/user.factory.dart`. Set the default values of the model in `definition`:

```dart title="db/factories/user.factory.dart"
import 'package:dox_orm/factory.dart';
import 'package:my_app/app/models/user/user.model.dart';

class UserFactory extends Factory<User> {
  @override
  User definition() {
    User user = User();
    user.name = 'Jane';
    user.email = 'jane@example.com';
    return user;
  }
}
```

`definition` runs once for each model, so random values are new each time. Import factories from `package:dox_orm/factory.dart`, because the main `dox_orm` import does not include them.

### Fake data

Dox has no fake data generator, but the [faker](https://pub.dev/packages/faker) package works well with factories:

```bash
dart pub add faker
```

```dart title="db/factories/user.factory.dart"
import 'package:dox_orm/factory.dart';
import 'package:faker/faker.dart';
import 'package:my_app/app/models/user/user.model.dart';

class UserFactory extends Factory<User> {
  @override
  User definition() {
    return User()
      ..name = faker.person.name()
      ..email = faker.internet.email();
  }
}
```

## Creating models

### Saving models

Use `create` to make models and save them. `count` sets how many you get, and the default is 1:

```dart
List<User> users = await UserFactory().count(10).create();
```

If you want only one model, use `createOne`:

```dart
User user = await UserFactory().createOne();
```

The models are saved one by one with `save()`. So [model events](model/events.md) run, and each model gets its id.

### Making models without saving

Sometimes you need a model but not a row in the database. Use `make` for a list, or `makeOne` for one model:

```dart
User user = UserFactory().makeOne();

List<User> users = UserFactory().count(3).make();
```

## States

A state changes each model after `definition`. Use it when you need a different kind of model, like an admin user. The examples below use a `bool? isAdmin` and a `String? role` field on `User`:

```dart
User admin = await UserFactory()
    .state((User u) => u..isAdmin = true)
    .createOne();
```

You can add more than one state. They run in the order you add them.

If you use a state often, put it in a method on the factory:

```dart
class UserFactory extends Factory<User> {
  @override
  User definition() => User()..name = 'Jane';

  UserFactory admin() {
    state((User u) => u..isAdmin = true);
    return this;
  }
}

List<User> admins = await UserFactory().admin().count(3).create();
```

Call your own methods first, because `count()` and `state()` return a `Factory<User>`, not a `UserFactory`.

### Sequences

Sometimes each model needs a different value. `sequence` is a state that also gets the index of the model: 0, 1, 2 and so on:

```dart
List<User> users = await UserFactory()
    .count(3)
    .sequence((User u, int i) => u..email = 'user$i@example.com')
    .create();
// user0@example.com, user1@example.com, user2@example.com
```

To switch between a few values, use the index:

```dart
List<String> roles = <String>['admin', 'editor'];
await UserFactory()
    .count(4)
    .sequence((User u, int i) => u..role = roles[i % roles.length])
    .create();
```

## Relationships

### Belongs to relationships

To make models that belong to a parent, set the parent key with a state:

```dart
User user = await UserFactory().createOne();

await PostFactory()
    .count(3)
    .state((Post p) => p..userId = user.id)
    .create();
```

### Has many relationships

`has` creates child models for each saved model. The second argument sets the parent on each child:

```dart
List<User> users = await UserFactory()
    .count(2)
    .has(PostFactory().count(3), (Post p, User u) => p..userId = u.id)
    .create();
// 2 users, each with 3 posts
```

`has` only works with `create` and `createOne`. `make` saves nothing, so it makes no children.

## Testing

A factory needs the ORM, so set it up first, the same as in your app. Then create the data your test needs:

```dart
import 'package:test/test.dart';

import '../db/factories/user.factory.dart';

void main() {
  test('lists users', () async {
    await UserFactory().count(3).create();
    // call your route and check the result
  });
}
```

See [Testing with a database](../guides/testing-with-database.md).

## Details

- Each call like `count()` or `state()` changes the factory and returns it. So make a new factory for each set of models.
