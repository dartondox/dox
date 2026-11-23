---
icon: lucide/shield-check
---

# Authorization

`dox_auth` lets you decide what a logged in user may do, with gates and policies.

[Authentication](authentication.md) tells you who the user is. Authorization tells you what this user may do. A **gate** is one rule, written as a function. A **policy** is a class with all the rules of one model, like `Post`.

## Setup

Gates and policies are kept per isolate. Add them in the `setup()` of a provider, because it runs in every isolate:

```dart title="lib/providers/gate_provider.dart"
import 'package:dox_auth/dox_auth.dart';
import 'package:dox_core/dox_core.dart';
import 'package:my_app/app/models/post/post.model.dart';
import 'package:my_app/app/models/user/user.model.dart';
import 'package:my_app/app/policies/post_policy.dart';

class GateProvider extends DoxProvider {
  @override
  void setup() {
    Gate.define('update-post',
        (User user, Post post) => post.userId == user.id);
    Gate.policy<Post>(PostPolicy());
  }
}
```

Run `dart run build_runner build` to add the provider to `lib/generated/container.g.dart`.

## Writing gates

A gate gets the user and a subject, and gives true when the user may do it. A check with another user or subject type is denied:

```dart
Gate.define('update-post',
    (User user, Post post) => post.userId == user.id);
```

For a gate with no subject, use `_` for the second parameter:

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

`Gate.allows` gives true when the user may do it, and `Gate.denies` gives the opposite:

```dart
if (await Gate.allows(user, 'update-post', post)) {
  // the user may update the post
}

if (await Gate.denies(user, 'create-post')) {
  // the user may not create a post
}
```

`Gate.authorize` throws when the check fails, and the client gets 403:

```dart
await Gate.authorize(user, 'update-post', post);
```

`Gate.any` checks that at least one ability is allowed. `Gate.all` checks that all are allowed:

```dart
await Gate.any(user, <String>['update-post', 'delete-post'], post);
await Gate.all(user, <String>['update-post', 'delete-post'], post);
```

An ability with no gate and no policy is always denied.

### Giving a reason

Return a `GateResponse` in place of a bool. The reason of `GateResponse.deny` becomes the message of the 403 answer:

```dart
Gate.define('delete-post', (User user, Post post) {
  if (post.published == true) {
    return GateResponse.deny('You can not delete a published post.');
  }
  return post.userId == user.id;
});
```

`Gate.inspect` gives the full answer. `authorize()` on it throws 403 when it is denied:

```dart
GateResponse response = await Gate.inspect(user, 'delete-post', post);
print(response.allowed); // or response.denied
print(response.message);
response.authorize();
```

## Writing policies

Put the rules of one model in a policy. Write one method per ability, then list the methods in `abilities`. A method takes the user, and the model when the ability needs one:

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

Register the policy for its model. A method with another signature than `(User user)` or `(User user, Post post)` fails here, when the app starts:

```dart
Gate.policy<Post>(PostPolicy());
```

Now a check with a `Post` subject uses the policy. For an ability with no model, like `create`, give the type `Post`:

```dart
await Gate.allows(user, 'update', post);
await Gate.allows(user, 'create', Post);
await Gate.authorize(user, 'delete', post);
```

When the policy has no method for an ability, Dox uses the gate with that name.

### Using the ability constants

The `Ability` constants let the compiler find a wrong ability name: `Ability.viewAny`, `Ability.view`, `Ability.create`, `Ability.update` and `Ability.delete`. `Ability.update` is the same as `'update'`:

```dart
Map<String, Function> get abilities => <String, Function>{
  Ability.update: update,
};

await Gate.allows(user, Ability.update, post);
```

## Finding rules

Check if a rule exists, for example in a package that makes code for models:

```dart
Gate.isDefined('update-post');         // a gate with this name
Gate.hasAbility<Post>('view');         // the Post policy has 'view'
Gate.policyOf<Post>()?.abilities.keys; // the Post policy, or null
```

## Authorizing in a controller

In a controller, use `req.authorize`, `req.can` and `req.cannot`. They use the user of `req.auth`, so put the route after `AuthMiddleware`:

```dart
Future<Post> update(DoxRequest req, Post post) async {
  await req.authorize('update', post);
  post.title = req.input('title');
  await post.save();
  return post;
}
```

`req.authorize` answers 401 for a guest and 403 for a user who may not do it. `req.can` gives a bool, for example for the front end:

```dart
Future<Map<String, dynamic>> show(DoxRequest req, Post post) async {
  return <String, dynamic>{
    'post': post,
    'can_edit': await req.can('update', post),
  };
}
```

## Authorizing on a route

The `Can` middleware checks an ability before the controller runs. Put it after `AuthMiddleware`:

```dart
// a gate with no subject
Route.get('/admin', <dynamic>[
  AuthMiddleware(),
  Can('view-admin'),
  adminController.index,
]);
```

For a policy method with no model, give the type with `subject`:

```dart
Route.post('/posts', <dynamic>[
  AuthMiddleware(),
  Can('create', subject: Post),
  postController.store,
]);
```

For a policy method with a model, use `param`. The subject is the value that `Route.bind` gives for that route param. When `Route.bind` finds nothing, the answer is 404:

```dart
Route.bind<Post>('post', (String id) => Post().find(id));
Route.put('/posts/{post}', <dynamic>[
  AuthMiddleware(),
  Can('update', param: 'post'),
  postController.update,
]);
```

A guest gets 401, and a logged in user who may not do it gets 403.

## Guest users

A gate or policy denies a guest. For a rule that also works for guests, make the user type nullable:

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

On a public route, use `AuthMiddleware(optional: true)`. It loads the user when the login is good, and lets guests through. Without it, a logged in user is a guest too:

```dart
Route.get('/posts/{post}', <dynamic>[
  AuthMiddleware(optional: true),
  Can('view-post', param: 'post'),
  postController.show,
]);
```

## Before and after hooks

`Gate.before` runs before every check. Return true or false to decide at once, or null to do the normal check:

```dart
Gate.before((User user, String ability) =>
    user.isAdmin == true ? true : null);
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
  bool? before(User user, String ability) =>
      user.isAdmin == true ? true : null;

  // ...
}
```

## Auth flags

Turn on opt-in behavior with `flags` in `AuthConfig`. All flags are off by default:

```dart
AuthConfig authConfig = AuthConfig(
  defaultGuard: 'web',
  guards: guards,
  flags: const AuthFlags(forbidGuest: true, jsonNoRedirect: true),
);
```

- `forbidGuest`: `req.authorize` and `Can` give a guest 403 with the gate message, not 401. `AuthMiddleware` still gives a guest 401.
- `jsonNoRedirect`: `AuthMiddleware(redirectTo: '/login')` gives a JSON client 401, not a redirect. A JSON client sends a JSON `Accept` header, a JSON body, or `X-Requested-With: XMLHttpRequest`. An Inertia request still gets the redirect.
- `endSessionsOnPasswordChange`: a session login ends when the password of the user changes. It also turns on `logoutOtherDevices`. See [Ending sessions when the password changes](authentication.md#end-other-sessions-when-the-password-changes).

`AuthFlags.all()` turns on every flag:

```dart
AuthConfig(defaultGuard: 'web', guards: guards,
    flags: const AuthFlags.all());
```

## Testing

`Gate.flush()` removes all gates, policies and hooks. Call it in `setUp` when each test adds its own rules. Policy methods are normal Dart methods, so a test can also call them directly.

## Next steps

- [Authentication](authentication.md): find out who the user is.
- [Middleware](../the-basic/middleware.md): run a check before a route.
