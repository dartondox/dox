---
icon: simple/graphql
---

# GraphQL

`dox_graphql` makes a GraphQL API for your app from your models.

GraphQL is an API with one URL. The client writes the fields that it wants, and it gets JSON with only those fields. One request can read a post, the user of the post, and its comments. To learn GraphQL, read [graphql.org/learn](https://graphql.org/learn/).

## Quick start

### Install

```bash
dox add graphql
```

The command adds the packages, `lib/config/graphql.dart`, and `lib/providers/graphql_provider.dart`. It does not overwrite a file.

### Add a model to the API

Put `@GraphQLType()` on a model:

```dart title="lib/app/models/post/post.model.dart"
import 'package:dox_graphql/dox_graphql.dart';
import 'package:dox_orm/dox_orm.dart';
import 'package:my_app/app/models/user/user.model.dart';

part 'post.model.g.dart';

@DoxModel()
@GraphQLType()
class Post extends PostGenerator {
  @Column()
  String? title;

  @Column()
  int? userId;

  @BelongsTo(User)
  User? user;
}
```

The `id`, the columns, and the relations of the model are now fields that a client can ask for. `Post` has a relation to `User`. Thus, put `@GraphQLType()` on `User` also.

Then run the builder and start the app again. Do these two steps after each change on this page:

```bash
dart run build_runner build
```

### Run a query

A **query** is a request that reads data. Dox gives each model two automatic queries. For `Post`, the queries are:

- `posts(limit, offset)`: a list of posts. The default `limit` is `20`, and the maximum is `100`. If the model has a policy with `view`, the list can have fewer rows than `limit` (see [Authorization](#authorization)).
- `post(id)`: one post. The result is `null` if no post has that id. With a `view` rule, the result can be the error `FORBIDDEN` (see [view](#view)).

Open `http://localhost:3000/graphql` in a browser. In development, this URL shows GraphiQL. GraphiQL is a page where you write and run queries. Run this query:

```graphql
{
  posts(limit: 10) {
    title
    user { name }
  }
}
```

The result has the same shape as the query:

```json
{ "data": { "posts": [{ "title": "Hello GraphQL", "user": { "name": "Ada" } }] } }
```

Dox loads the users of all ten posts with one database query.

Your client sends the same query as a `POST` request to `/graphql`. The JSON body is `{"query": "..."}`.

### Hide a field

Some columns must not be visible to a client. Dox does not show the fields in the `hidden` list of the model. Thus, a password is never visible. To hide a different field, put `@GraphQLIgnore()` on the line above its `@Column()`.

### Turn off the automatic queries

Sometimes a client must get a model only through a relation, for example `post.user`. For this model, write `@GraphQLType(queries: false)`. Then the model does not get its own queries.

To turn off the automatic queries and mutations of all models, set `autoResolvers: false` in the [configuration](#configuration).

## Write your own query

Write your own query when the automatic queries are not sufficient, for example for a search or a top-ten list. Put `@GraphQLQuery()` on a method of a class in `lib/`. This method is a **resolver**. A resolver is your code that gives the result of the query.

```dart title="lib/app/graphql/post.resolver.dart"
import 'package:dox_graphql/dox_graphql.dart';
import 'package:my_app/app/models/post/post.model.dart';
import 'package:my_app/app/services/post.service.dart';

class PostResolver {
  PostResolver(this.postService);

  final PostService postService;

  @GraphQLQuery()
  Future<List<Post>> trendingPosts({int limit = 10}) {
    return postService.trending(limit);
  }
}
```

Run the builder and start the app again. The builder finds the class automatically. Dox gets the other data from the method:

- The method name is the query name: `trendingPosts`.
- The parameters are the values that a client can send. A parameter with a default value is optional.
- The return type is the type that the client gets.
- Dox gets the constructor parameters from the [container](../the-basic/dependency-injection.md).

A client calls the query like this: `{ trendingPosts(limit: 3) { title } }`.

### Send an error to the client

To send your own message, throw a `GraphQLError`. For example: `throw GraphQLError('This post is not published yet');`.

For all other errors, the client sees "Internal server error" in production. Dox sends the real error to the `ExceptionHandler` of your app.

## Create, update, and delete

A **mutation** is a request that changes data. Dox can make the create, update, and delete mutations of a model for you.

### Create

Write a [DTO](../the-basic/dto.md) with the fields that a client can set:

```dart title="lib/app/dtos/create_post/create_post.dto.dart"
import 'package:dox_core/dox_core.dart';

part 'create_post.dto.g.dart';

@Dto()
class CreatePostDto {
  CreatePostDto({required this.title});

  @MinLength(3, message: 'The title is too short')
  final String title;
}
```

Give the DTO to the model with `dto:`. Then run the builder:

```dart title="lib/app/models/post/post.model.dart"
@DoxModel()
@GraphQLType(dto: CreatePostDto)
class Post extends PostGenerator {}
```

The API now has `createPost`:

```graphql
mutation {
  createPost(input: { title: "My second post" }) { id title }
}
```

A client can set only the fields of the DTO. Thus, a client cannot set a different column, for example `userId`.

To set `userId` to the logged-in user, add `owner:`. Then a client must log in to create, update or delete a post.

```dart
@GraphQLType(dto: CreatePostDto, owner: 'userId')
```

Dox applies the rules of the DTO before it saves the post. If the input is not correct, Dox saves nothing. The client gets the error `VALIDATION_FAILED`, with the message for each field in `extensions.fields`.

### Update and delete

Update and delete change a row that exists. Thus, Dox must know who can change the row. A policy gives this data. Dox makes `updatePost` and `deletePost` only for a model with `dto:` and `policy:`. See [Authorization](#authorization).

`updatePost` changes only the fields that the client sends. Dox applies only the rules of those fields.

### Write your own mutation

Write your own mutation when one saved row is not sufficient. Put `@GraphQLMutation()` on a resolver method, and use a DTO for the input. Dox applies the rules of the DTO before your method runs.

```dart title="lib/app/graphql/post.resolver.dart"
@GraphQLMutation()
Future<Post> importPost(CreatePostDto input) {
  return postService.import(input);
}
```

## Authentication

By default, all clients can call all queries and mutations. To make clients log in, use `AuthMiddleware` from `dox_auth`. If your app does not have a login, set it up first with [`dox add auth`](../security/authentication.md).

Add `AuthMiddleware()` to the config:

```dart title="lib/config/graphql.dart"
import 'package:dox_auth/dox_auth.dart';
import 'package:dox_graphql/dox_graphql.dart';
import 'package:my_app/generated/schema.g.dart';

GraphQLConfig graphqlConfig = GraphQLConfig(
  schema: graphqlSchema,
  middleware: <Object>[AuthMiddleware()],
);
```

Now each query, each mutation, and each relation, for example `post.user`, needs a logged-in user. The client sends its token in the `Authorization: Bearer <token>` header, as usual.

If a guest asks for a protected field, the guest gets the error `UNAUTHENTICATED` for that field. Public fields in the same request still give their data. To make this possible, each query, each mutation and each relation can be `null` in the schema. A field that can refuse a guest can be `null` too. In development, the GraphiQL page stays open, but it shows no data to a guest.

### Make a query, mutation or field public

In GraphQL, a query is a field of the `Query` type, and a mutation is a field of the `Mutation` type. Thus, one setting makes each of them public. Set `auth: false` on the fields that a guest can use:

```dart title="lib/app/graphql/post.resolver.dart"
@GraphQLQuery(auth: false)
Future<List<Post>> trendingPosts({int limit = 10}) {
  return postService.trending(limit);
}
```

`auth: false` works the same on `@GraphQLMutation`.

On a model, `@GraphQLType(auth: false)` makes the model public everywhere. This includes its automatic queries and mutations, and all relations that give the model.

A public query does not make the relations in it public. If `trendingPosts` is public, a guest gets the `title` of each post. But `user` in a post still needs a login. To make `user` public, set `auth: false` on `User` also.

### Protect a model everywhere

Write `@GraphQLType(auth: true)` on a model that a guest must never see, for example `User`. Then each field that gives a user needs a login. This is also true in a public query.

`auth: true` needs `AuthMiddleware()` in the config. If the config does not have it, the app stops at start and shows the name of the type or field.

### Read the logged-in user

Add a `DoxGraphQLContext` parameter to a resolver method. The client does not send this value. Dox puts the current request in it:

```dart title="lib/app/graphql/user.resolver.dart"
@GraphQLQuery()
Future<User?> me(DoxGraphQLContext context) {
  return context.user<User>();
}
```

`context.user<User>()` gives `null` for a guest.

## Authorization

A policy decides who can read or change a row. Authentication finds who the user is. The policy uses that user to allow or refuse each request.

### Write a policy

A policy is a class with one method for each rule. The `abilities` map gives a name to each method. Dox reads these names: `viewAny`, `view`, `create`, `update` and `delete`.

```dart title="lib/app/policies/post_policy.dart"
import 'package:dox_auth/dox_auth.dart';
import 'package:my_app/app/models/post/post.model.dart';
import 'package:my_app/app/models/user/user.model.dart';

class PostPolicy extends Policy<User, Post> {
  bool update(User user, Post post) => post.userId == user.id;

  @override
  Map<String, Function> get abilities => <String, Function>{
    'update': update,
  };
}
```

Dox checks only the names that are in `abilities`. This policy has no `view`. Thus, each user can read each post. Your method can have a different name, but the name in `abilities` must be one of the five names.

Each section below adds one method to this policy. Add each new method to `abilities` also. To learn more about policies, read [Writing policies](../security/authorization.md#writing-policies).

### Use it on a model

Register the policy in the `setup()` of the GraphQL provider. `dox add graphql` made this provider. Keep the `super.setup()` call:

```dart title="lib/providers/graphql_provider.dart"
class AppGraphQLProvider extends GraphQLProvider {
  AppGraphQLProvider() : super(graphqlConfig);

  @override
  void setup() {
    Gate.policy<Post>(PostPolicy());
    super.setup();
  }
}
```

Then give the policy to the model with `policy:`, and run the builder:

```dart title="lib/app/models/post/post.model.dart"
@DoxModel()
@GraphQLType(dto: CreatePostDto, policy: PostPolicy)
class Post extends PostGenerator {
  @Column()
  String? title;

  @Column()
  String? status;

  @Column()
  int? userId;
}
```

`dto:` is optional. Without `dto:`, the model has the automatic queries with the policy checks, and no mutations.

### viewAny

Use `viewAny` when some users must not get lists of the model. It guards the `posts` query and each relation that gives posts, for example `user.posts`.

```dart
bool viewAny(User user) => user.banned != true;
```

A banned user sends this request:

```graphql
{
  posts { title }
  me { name }
}
```

The `posts` field is `null`. The other fields keep their data:

```json
{ "data": { "posts": null, "me": { "name": "Ada" } } }
```

The `errors` list of the result has one error for `posts`. Its code is `FORBIDDEN`, in `extensions.code`.

### view

Use `view` when a user can read some rows and not others. Here, a user can read a published post and their own posts:

```dart
bool view(User user, Post post) {
  return post.status == 'published' || post.userId == user.id;
}
```

Post 2 is a draft of a different user:

```graphql
{ post(id: 2) { title } }
```

```json
{ "data": { "post": null } }
```

The error code is `FORBIDDEN`.

In a list, Dox removes the rows that `view` refuses, and gives no error. This is true for the `posts` query and for a list relation, for example `user.posts`. A single relation to a refused row, for example `comment.post`, is `null` with no error.

### create

Use `create` when only some users can add a row. The method gets only the user, because no row exists yet:

```dart
bool create(User user) => user.verified == true;
```

A user that is not verified sends this request:

```graphql
mutation {
  createPost(input: { title: "My first post" }) { id }
}
```

```json
{ "data": { "createPost": null } }
```

The error code is `FORBIDDEN`, and Dox saves nothing. Dox asks the policy first. It applies the rules of the DTO only for a user that the policy allows.

### update

Use `update` to decide who can change a row. The API has `updatePost` only when the model has `dto:` and `policy:`.

```dart
bool update(User user, Post post) => post.userId == user.id;
```

Post 1 belongs to a different user:

```graphql
mutation {
  updatePost(id: 1, input: { title: "A better title" }) { title }
}
```

```json
{ "data": { "updatePost": null } }
```

The error code is `FORBIDDEN`, and Dox writes nothing.

If no row has the id, Dox asks the policy about an empty post. Thus, a refused user gets `FORBIDDEN` for each id. This is the same for `view` and `delete`.

### delete

Use `delete` to decide who can remove a row. The API has `deletePost` only when the model has `dto:` and `policy:`.

```dart
bool delete(User user, Post post) => post.userId == user.id;
```

Post 1 belongs to a different user:

```graphql
mutation {
  deletePost(id: 1)
}
```

```json
{ "data": { "deletePost": null } }
```

The error code is `FORBIDDEN`, and the post stays in the database. For the owner of the post, the result is `true`.

### Let guests in

A guest is a client that is not logged in. The first type of the policy decides what a guest gets.

With `Policy<User, Post>`, your methods always get a user. Dox refuses each guest. Where a user gets `FORBIDDEN`, a guest gets the error `UNAUTHENTICATED`.

With `Policy<User?, Post>`, a guest gets to your methods, and `user` is `null`. Use it when a guest can read some rows:

```dart
class PostPolicy extends Policy<User?, Post> {
  bool view(User? user, Post post) {
    if (post.status == 'published') return true;
    return user != null && post.userId == user.id;
  }

  @override
  Map<String, Function> get abilities => <String, Function>{'view': view};
}
```

Now a guest can read the published posts, and a user can also read their own drafts.

If the config has `AuthMiddleware()`, the model also needs `auth: false`. See [Make a query, mutation or field public](#make-a-query-mutation-or-field-public).

A model with `owner:` always needs a login for create, update and delete.

### Your own resolvers

The policy checks run only in the queries, mutations and relations that Dox makes for a model. In your own `@GraphQLQuery`, `@ResolveField` or getter that returns a model, call [`Gate`](../security/authorization.md#checking-a-gate) yourself:

```dart title="lib/app/graphql/post.resolver.dart"
@GraphQLQuery()
Future<Post?> latestPost(DoxGraphQLContext context) async {
  Post? post = await postService.latest();
  User? user = await context.user<User>();
  if (post != null && await Gate.denies(user, 'view', post)) {
    throw GraphQLAuth.forbidden();
  }
  return post;
}
```

`GraphQLAuth.forbidden()` gives the same `FORBIDDEN` error as the automatic checks.

## Configuration

All settings are fields of `GraphQLConfig` in `lib/config/graphql.dart`, for example `path: '/api/graphql'`. Each setting in the table has a default. Set only the settings that you want to change.

| Setting | Default | What it does |
|---|---|---|
| `path` | `/graphql` | The URL of the API. |
| `middleware` | none | Route middleware, like `AuthMiddleware()`. |
| `autoResolvers` | `true` | `false` turns off the free queries and mutations of all models. |
| `graphiql` | on in development | The GraphiQL page. |
| `introspection` | on in development | Lets tools like GraphiQL read the list of your types and fields. |
| `showInternalErrors` | on in development | Sends the real text of an error to the client. |
| `maxDepth` | `64` | How deep a query can nest fields. |
| `maxFields` | `20000` | The most fields one query can ask for. |
| `maxNodes` | `100000` | The most values one request can load. |
| `maxRootFields` | `50` | The most top-level fields in one request. Each alias counts. |
| `maxRelationRows` | `50000` | The most rows that one relation can load for all parent rows together. |

"On in development" means on when `APP_ENV` is `development`. Thus, in production, GraphiQL is off, nobody can get a list of your fields, and error details stay on the server. You do not change anything for this.

The `max` settings stop a very large query before it causes much work on your server. Set lower values when your API is open to the public.

## Without the ORM

If your app does not use models, install with `dox add graphql --no-orm`. Put `@GraphQLType()` on a plain Dart class. Its public fields are the fields that a client can ask for. You write all the queries yourself:

```dart title="lib/app/graphql/product.resolver.dart"
import 'package:dox_graphql/dox_graphql.dart';
import 'package:my_app/app/repositories/product.repository.dart';
import 'package:my_app/app/repositories/shop.repository.dart';

@GraphQLType()
class Product {
  Product({required this.id, required this.name, required this.shopId});

  final int id;
  final String name;

  @GraphQLIgnore()
  final int shopId;
}

class ProductResolver {
  ProductResolver(this.productRepository, this.shopRepository);

  final ProductRepository productRepository;
  final ShopRepository shopRepository;

  @GraphQLQuery()
  Future<List<Product>> products({int limit = 20}) {
    return productRepository.latest(limit);
  }

  @ResolveField()
  Future<Shop?> shop(Product product, DoxGraphQLContext context) {
    DataLoader<int, Shop> shops = context.loader<int, Shop>(
      'shops',
      () => DataLoader<int, Shop>(shopRepository.findByIds),
    );
    return shops.load(product.shopId);
  }
}
```

`@ResolveField()` adds a field to the class of its first parameter. Thus, `Product` gets a `shop` field, and `Shop` also needs `@GraphQLType()`.

The `DataLoader` collects the shop ids of the full request. Thus, fifty products cause one shop query, not fifty queries. `findByIds` takes a `List<int>` and returns a `Future<List<Shop?>>`, in the same order as the ids.
