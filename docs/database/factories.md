---
icon: lucide/factory
---

# Factories

A factory makes models with sample data.
Use it in tests and in [seeders](seeders.md).

## Create a factory

```bash
dox make:factory User
```

This makes `db/factories/user.factory.dart`:

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

`definition()` gives one new model with the default values.
It runs once for each model, so random values are new each time.

## Make and create

| Method | What it gives |
| --- | --- |
| `make()` | a list of models. They are not saved. |
| `makeOne()` | one model. It is not saved. |
| `create()` | a list of models, saved with `save()`. |
| `createOne()` | one model, saved with `save()`. |

`count(n)` sets how many models `make()` and `create()` give. The default is 1.

```dart
List<User> users = await UserFactory().count(10).create();

User user = UserFactory().makeOne();
```

`create()` saves the models one by one with `save()`.
So [model events](model/events.md) run, and each model gets its id.

## State

`state()` changes each model after `definition()`.

```dart
User admin = await UserFactory()
    .state((User u) => u..isAdmin = true)
    .createOne();
```

You can add more than one state. They run in the order you add them.

A factory method makes a state easy to use again:

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

Call your own methods first. `count()` and `state()` return a `Factory<User>`, not a `UserFactory`.

## Sequence

`sequence()` is a state that also gets the index of the model: 0, 1, 2 and so on.

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

## Relations

### Belongs to

Set the parent key with a state:

```dart
User user = await UserFactory().createOne();

await PostFactory()
    .count(3)
    .state((Post p) => p..userId = user.id)
    .create();
```

### Has many

`has()` creates child models for each saved model.
The second argument sets the parent on each child.

```dart
List<User> users = await UserFactory()
    .count(2)
    .has(PostFactory().count(3), (Post p, User u) => p..userId = u.id)
    .create();
// 2 users, each with 3 posts
```

`has()` only works with `create()` and `createOne()`. `make()` saves nothing, so it makes no children.

## Fake data

Dox has no fake data generator.
The [faker](https://pub.dev/packages/faker) package works well with factories:

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

## Use in tests

A factory needs the ORM. Set it up first, the same as in your app.

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

## Notes

- Each call like `count()` or `state()` changes the factory and returns it.
  Make a new factory for each set of models.
- Import factories from `package:dox_orm/factory.dart`. The main `dox_orm` import does not include them.
