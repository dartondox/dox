---
icon: lucide/factory
---

# Factories

A factory makes models with sample data, so you can fill the database quickly in tests and [seeders](seeders.md).

## Setup

`make:factory` makes a factory:

```bash
dox make:factory User
```

This makes `db/factories/user.factory.dart`. Set the default values in `definition`:

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

`definition` runs once for each model. Import factories from `package:dox_orm/factory.dart`, because the main import does not have them.

### Fake data

The [faker](https://pub.dev/packages/faker) package gives random values:

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

`create` makes models and saves them. `count` sets how many, 1 by default:

```dart
List<User> users = await UserFactory().count(10).create();
```

`createOne` makes and saves one model:

```dart
User user = await UserFactory().createOne();
```

Each model is saved with `save()`, so [model events](model/events.md) run.

### Making models without saving

`make` gives a list, and `makeOne` gives one model. They save nothing:

```dart
User user = UserFactory().makeOne();
List<User> users = UserFactory().count(3).make();
```

## States

A state changes each model after `definition`:

```dart
User admin = await UserFactory()
    .state((User u) => u..isAdmin = true)
    .createOne();
```

States run in the order you add them. Put a state you use often in a method of the factory:

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

Call your own methods first, because `count()` and `state()` return a `Factory<User>`.

### Sequences

`sequence` is a state that also gets the index of the model, from 0:

```dart
List<User> users = await UserFactory()
    .count(3)
    .sequence((User u, int i) => u..email = 'user$i@example.com')
    .create();
// user0@example.com, user1@example.com, user2@example.com
```

## Relationships

### Belongs to relationships

Set the parent key with a state:

```dart
User user = await UserFactory().createOne();

await PostFactory()
    .count(3)
    .state((Post p) => p..userId = user.id)
    .create();
```

### Has many relationships

`has` creates children for each saved model. The function sets the parent on each child:

```dart
List<User> users = await UserFactory()
    .count(2)
    .has(PostFactory().count(3), (Post p, User u) => p..userId = u.id)
    .create();
// 2 users, each with 3 posts
```

`has` works only with `create` and `createOne`.

## Testing

Set up the ORM first, like in your app. Then create the data the test needs:

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

Each call like `count()` changes the factory, so make a new factory for each set of models. See [Testing with a database](../guides/testing-with-database.md).

## Next steps

- [Seeders](seeders.md): fill the database with factories.
- [Model](model/index.md): the models a factory makes.
- [Testing with a database](../guides/testing-with-database.md): data for each test.
