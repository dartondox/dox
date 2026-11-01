---
icon: lucide/shield-check
---

# Authorization

This page shows how to say what a user may do, with gates and policies from `dox_auth`.

[Authentication](authentication.md) says who the user is.
Authorization says what this user may do.
For example, a user may edit their own post, but not the post of another user.

There are two ways to write the rules:

- A **gate** is one rule, written as a function.
- A **policy** is a class with all the rules of one model, like `Post`.

## Register the rules

Gates and policies are kept per isolate.
Dox runs many isolates, so add them in a provider.
The `setup()` of a provider runs in every isolate.

```dart title="lib/providers/gate_provider.dart"
import 'package:dox_auth/dox_auth.dart';
import 'package:dox_core/dox_core.dart';
import 'package:my_app/app/models/post/post.model.dart';
import 'package:my_app/app/models/user/user.model.dart';
import 'package:my_app/app/policies/post_policy.dart';

class GateProvider extends DoxProvider {
  @override
  void setup() {
    Gate.define('update-post', (User user, Post post) => post.userId == user.id);
    Gate.policy<Post>(PostPolicy());
  }
}
```

Dox finds the provider by itself. Run `dart run build_runner build` and it is in `lib/generated/container.g.dart`.

## Gates

A gate gets the user and a subject. It gives `true` when the user may do it.
The user and subject types come from the function.
A check with another type is denied.

```dart
Gate.define('update-post', (User user, Post post) => post.userId == user.id);
```

A gate with no subject uses `_` for the second parameter:

```dart
Gate.define('create-post', (User user, _) => user.verified == true);
```

A gate can be async:

```dart
Gate.define('publish-post', (User user, Post post) async {
  return await user.canPublishIn(post.categoryId);
});
```

### Check a gate

```dart
if (await Gate.allows(user, 'update-post', post)) {
  // the user may update the post
}

if (await Gate.denies(user, 'create-post')) {
  // the user may not create a post
}

// stop the request with 403 when denied
await Gate.authorize(user, 'update-post', post);

// true when the user may do at least one, or all of them
await Gate.any(user, <String>['update-post', 'delete-post'], post);
await Gate.all(user, <String>['update-post', 'delete-post'], post);
```

An ability with no gate and no policy is denied.

### Give a reason

A check can give a `GateResponse` instead of a `bool`.
The reason of `GateResponse.deny` is the message of the 403 answer.

```dart
Gate.define('delete-post', (User user, Post post) {
  if (post.published == true) {
    return GateResponse.deny('You can not delete a published post.');
  }
  return post.userId == user.id;
});

GateResponse response = await Gate.inspect(user, 'delete-post', post);
print(response.allowed);
print(response.message);
```

## Policies

A policy holds the rules of one model.
Write one method per ability.
A method takes the user, and the model when the ability needs one.
List the methods in `abilities`.

```dart title="lib/app/policies/post_policy.dart"
import 'package:dox_auth/dox_auth.dart';
import 'package:my_app/app/models/post/post.model.dart';
import 'package:my_app/app/models/user/user.model.dart';

class PostPolicy extends Policy<User, Post> {
  bool create(User user) => user.verified == true;

  bool update(User user, Post post) => post.userId == user.id;

  bool delete(User user, Post post) => post.userId == user.id;

  @override
  Map<String, Function> get abilities => <String, Function>{
    'create': create,
    'update': update,
    'delete': delete,
  };
}
```

Add the policy for its model:

```dart
Gate.policy<Post>(PostPolicy());
```

A check with a `Post` as the subject now uses the policy.
For an ability with no model, like `create`, pass the type `Post`:

```dart
await Gate.allows(user, 'update', post);
await Gate.allows(user, 'create', Post);
await Gate.authorize(user, 'delete', post);
```

Each method must take `(User user)` or `(User user, Post post)`.
A method with another signature fails at `Gate.policy`, so you see the mistake when the app starts.

When the policy has no method with the ability name, the gate with that name is used.

!!! note "Why a map of methods"
    Dart has no runtime reflection in compiled apps.
    So Dox can not find a method by its name.
    The `abilities` map links each name to its method.
    The methods stay normal typed Dart methods, so you can also call them directly in a test.

## In a controller

`req.can`, `req.cannot` and `req.authorize` use the logged-in user of `req.auth`.
Use them after `AuthMiddleware`.

```dart
Future<Post> update(DoxRequest req, Post post) async {
  await req.authorize('update', post);
  post.title = req.input('title');
  await post.save();
  return post;
}

Future<Map<String, dynamic>> show(DoxRequest req, Post post) async {
  return <String, dynamic>{
    'post': post,
    'can_edit': await req.can('update', post),
  };
}
```

`req.authorize` answers `401` for a guest and `403` for a user who may not do it.

## On a route

The `Can` middleware checks an ability before the controller runs.
Put it after `AuthMiddleware`.

```dart
// a gate with no subject
Route.get('/admin', <dynamic>[AuthMiddleware(), Can('view-admin'), adminController.index]);

// a policy method with no model
Route.post('/posts', <dynamic>[AuthMiddleware(), Can('create', subject: Post), postController.store]);

// a policy method with the model of the route param
Route.bind<Post>('post', (String id) => Post().find(id));
Route.put('/posts/{post}', <dynamic>[AuthMiddleware(), Can('update', param: 'post'), postController.update]);
```

With `param`, the subject is the value of `Route.bind` for that route param.
When `Route.bind` finds nothing, the answer is `404`.

The answers:

- A guest who may not do it gets `401`.
- A logged-in user who may not do it gets `403`.

## Guests

A guest has no user. The user is `null`.
A gate or a policy is denied for a guest, unless its user type is nullable:

```dart
Gate.define('view-post', (User? user, Post post) {
  return post.published == true || post.userId == user?.id;
});

class CommentPolicy extends Policy<User?, Comment> {
  bool view(User? user, Comment comment) => comment.visible == true;

  @override
  Map<String, Function> get abilities => <String, Function>{'view': view};
}
```

`Can('view-post', param: 'post')` without `AuthMiddleware` then works for guests too.

## Before and after hooks

`Gate.before` runs before every check.
It gives `true` or `false` to decide at once, or `null` to go on with the normal check.
For example, an admin may do anything:

```dart
Gate.before((User user, String ability) => user.isAdmin == true ? true : null);
```

A hook runs only for users of its type. A `User` hook does not run for guests.

`Gate.after` sees the answer of every check, for example to log it.
It can not change the answer.

```dart
Gate.after((User user, String ability, GateResponse response) {
  print('${user.id} $ability ${response.allowed}');
});
```

A policy can have its own `before`. It runs before the methods of that policy:

```dart
class PostPolicy extends Policy<User, Post> {
  @override
  bool? before(User user, String ability) => user.isAdmin == true ? true : null;

  // ...
}
```

## In tests

`Gate.flush()` removes all gates, policies and hooks.
Call it in `setUp` when each test adds its own rules.
