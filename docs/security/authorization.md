---
icon: lucide/shield-check
---

# Authorization

`dox_auth` lets you decide what a logged in user may do, with gates and policies.

[Authentication](authentication.md) tells you who the user is. Authorization tells you what this user may do. For example, a user may edit their own post, but not the post of another user.

There are two ways to write the rules:

- A **gate** is one rule, written as a function.
- A **policy** is a class with all the rules of one model, like `Post`.

## Registering the rules

Gates and policies are kept per isolate. Dox runs many isolates, so add them in the `setup()` of a provider, because it runs in every isolate:

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

Dox finds the provider by itself. Run `dart run build_runner build` to add it to `lib/generated/container.g.dart`.

## Writing gates

A gate gets the user and a subject, and gives `true` when the user may do it. The user and subject types come from the function, so a check with another type is denied:

```dart
Gate.define('update-post', (User user, Post post) => post.userId == user.id);
```

If the gate needs no subject, use `_` for the second parameter:

```dart
Gate.define('create-post', (User user, _) => user.verified == true);
```

A gate can also be async:

```dart
Gate.define('publish-post', (User user, Post post) async {
  return await user.canPublishIn(post.categoryId);
});
```

## Checking a gate

Use `Gate.allows` to check if the user may do something:

```dart
if (await Gate.allows(user, 'update-post', post)) {
  // the user may update the post
}
```

`Gate.denies` is the opposite:

```dart
if (await Gate.denies(user, 'create-post')) {
  // the user may not create a post
}
```

If you want to stop the request when the check fails, use `Gate.authorize`. It throws, and the client gets a `403`:

```dart
await Gate.authorize(user, 'update-post', post);
```

To check many abilities at once, use `Gate.any` (at least one) or `Gate.all` (all of them):

```dart
await Gate.any(user, <String>['update-post', 'delete-post'], post);
await Gate.all(user, <String>['update-post', 'delete-post'], post);
```

An ability with no gate and no policy is always denied.

### Giving a reason

Sometimes you want to tell the user why they may not do something. Return a `GateResponse` instead of a `bool`. The reason of `GateResponse.deny` becomes the message of the `403` answer:

```dart
Gate.define('delete-post', (User user, Post post) {
  if (post.published == true) {
    return GateResponse.deny('You can not delete a published post.');
  }
  return post.userId == user.id;
});
```

`Gate.inspect` gives you the full answer:

```dart
GateResponse response = await Gate.inspect(user, 'delete-post', post);
print(response.allowed);
print(response.message);
```

## Writing policies

When a model has many rules, put them in a policy. Write one method per ability. A method takes the user, and the model when the ability needs one. Then list the methods in `abilities`:

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

The `abilities` map is needed because compiled Dart apps can not find a method by its name.

Register the policy for its model:

```dart
Gate.policy<Post>(PostPolicy());
```

Now a check with a `Post` as the subject uses the policy. For an ability with no model, like `create`, pass the type `Post`:

```dart
await Gate.allows(user, 'update', post);
await Gate.allows(user, 'create', Post);
await Gate.authorize(user, 'delete', post);
```

Each method must take `(User user)` or `(User user, Post post)`. A method with another signature fails at `Gate.policy`, so you see the mistake when the app starts.

## Authorizing in a controller

In a controller, use `req.authorize`, `req.can` and `req.cannot`. They use the logged in user of `req.auth`, so put the route after `AuthMiddleware`:

```dart
Future<Post> update(DoxRequest req, Post post) async {
  await req.authorize('update', post);
  post.title = req.input('title');
  await post.save();
  return post;
}
```

`req.can` gives a `bool`, for example to tell the front end what the user may do:

```dart
Future<Map<String, dynamic>> show(DoxRequest req, Post post) async {
  return <String, dynamic>{
    'post': post,
    'can_edit': await req.can('update', post),
  };
}
```

`req.authorize` answers `401` for a guest and `403` for a user who may not do it.

## Authorizing on a route

The `Can` middleware checks an ability before the controller runs. Put it after `AuthMiddleware`:

```dart
// a gate with no subject
Route.get('/admin', <dynamic>[AuthMiddleware(), Can('view-admin'), adminController.index]);
```

For a policy method with no model, pass the type with `subject`:

```dart
// a policy method with no model
Route.post('/posts', <dynamic>[AuthMiddleware(), Can('create', subject: Post), postController.store]);
```

For a policy method with a model, use `param`. The subject is then the value that `Route.bind` gives for that route param. When `Route.bind` finds nothing, the answer is `404`:

```dart
// a policy method with the model of the route param
Route.bind<Post>('post', (String id) => Post().find(id));
Route.put('/posts/{post}', <dynamic>[AuthMiddleware(), Can('update', param: 'post'), postController.update]);
```

A guest who may not do it gets `401`, and a logged in user who may not do it gets `403`.

## Guest users

A guest has no user, so a gate or policy is denied for a guest. If you want a rule that also works for guests, make the user type nullable:

```dart
Gate.define('view-post', (User? user, Post post) {
  return post.published == true || post.userId == user?.id;
});
```

The same works in a policy:

```dart
class CommentPolicy extends Policy<User?, Comment> {
  bool view(User? user, Comment comment) => comment.visible == true;

  @override
  Map<String, Function> get abilities => <String, Function>{'view': view};
}
```

On a public route, use `AuthMiddleware(optional: true)`. It loads the user when the login is good, and lets guests through. Without it, nothing loads the user, so a logged in user is a guest too:

```dart
Route.get('/posts/{post}', <dynamic>[AuthMiddleware(optional: true), Can('view-post', param: 'post'), postController.show]);
```

## Before and after hooks

Sometimes one user may do everything, like an admin. `Gate.before` runs before every check. Return `true` or `false` to decide at once, or `null` to go on with the normal check:

```dart
Gate.before((User user, String ability) => user.isAdmin == true ? true : null);
```

A hook runs only for users of its type, so a `User` hook does not run for guests.

`Gate.after` sees the answer of every check, for example to log it. It can not change the answer:

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

## Auth flags

Some behaviors are opt-in. Turn them on with `flags:` in `AuthConfig`. All flags are off by default:

```dart
AuthConfig authConfig = AuthConfig(
  defaultGuard: 'web',
  guards: guards,
  flags: const AuthFlags(forbidGuest: true, jsonNoRedirect: true),
);
```

- `forbidGuest`: `req.authorize` and `Can` give a guest `403` with the gate message, not `401`. `AuthMiddleware` still gives a guest `401`.
- `jsonNoRedirect`: `AuthMiddleware(redirectTo: '/login')` gives a JSON or XHR client a `401`, not a redirect. An Inertia request still gets the redirect.
- `endSessionsOnPasswordChange`: a session login ends when the user's password changes. It also turns on `logoutOtherDevices`. See [Ending sessions when the password changes](authentication.md#end-other-sessions-when-the-password-changes).

`AuthFlags.all()` turns on every flag:

```dart
AuthConfig(defaultGuard: 'web', guards: guards, flags: const AuthFlags.all());
```

## Testing

`Gate.flush()` removes all gates, policies and hooks. Call it in `setUp` when each test adds its own rules.

## Details

- A JSON client is a request with a json `Accept` header, a JSON body, or `X-Requested-With: XMLHttpRequest`.
- When a policy has no method for an ability, the gate with that name is used.
- Policy methods are normal typed Dart methods, so you can also call them directly in a test.
- The flags are part of `AuthConfig`, and `Auth.initialize` runs in every isolate, so every isolate gets the same flags.
