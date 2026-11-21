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

Put `@GraphQL()` on a model. Then add one annotation for each operation that a client can use:

```dart title="lib/app/models/post/post.model.dart"
import 'package:dox_graphql/dox_graphql.dart';
import 'package:dox_orm/dox_orm.dart';
import 'package:my_app/app/models/user/user.model.dart';

part 'post.model.g.dart';

@DoxModel()
@GraphQL()
@GraphQLAll()
@GraphQLFind()
class Post extends PostGenerator {
  @Column()
  String? title;

  @Column()
  int? userId;

  @BelongsTo(User)
  User? user;
}
```

The `id`, the columns, and the relations of the model are now fields that a client can ask for. `@GraphQLAll()` adds the `posts` query, and `@GraphQLFind()` adds the `post` query. An operation that has no annotation does not exist.

`Post` has a relation to `User`. Thus, put `@GraphQL()` on `User` also.

Then run the builder and start the app again. Do these two steps after each change on this page:

```bash
dart run build_runner build
```

### Run a query

A **query** is a request that reads data. Open `http://localhost:3000/graphql` in a browser. In development, this URL shows GraphiQL. GraphiQL is a page where you write and run queries. Run this query:

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

### Give a model only through a relation

Sometimes a client must get a model only through a relation, for example `post.user`. Put only `@GraphQL()` on this model. Then the model has no queries and no mutations of its own.

## Model annotations

Each annotation adds one query or one mutation to the API. This model uses all of them:

```dart title="lib/app/models/post/post.model.dart"
@DoxModel()
@GraphQL()
@GraphQLAll()
@GraphQLPaginate()
@GraphQLFind()
@GraphQLCreate(dto: PostInput)
@GraphQLUpdate(dto: PostInput)
@GraphQLDelete()
class Post extends PostGenerator {}
```

| Annotation | GraphQL field |
|---|---|
| `@GraphQL()` | The `Post` type. No query and no mutation. |
| `@GraphQLAll()` | `posts(limit, offset)` |
| `@GraphQLPaginate()` | `posts(first, page)`, or `postsPaginate(first, page)` if the model also has `@GraphQLAll()` |
| `@GraphQLFind()` | `post(id)` |
| `@GraphQLCreate(dto:)` | `createPost(input)` |
| `@GraphQLUpdate(dto:)` | `updatePost(id, input)` |
| `@GraphQLDelete()` | `deletePost(id)` |

Each annotation can have these options:

| Option | Function |
|---|---|
| `name:` | A different name for the type or the field. |
| `description:` | The text that GraphiQL shows. |
| `guard: true` | A client must log in. See [Authentication](#authentication). |
| `can:` | The policy must allow the user. `@GraphQL` does not have this option. See [Authorization](#authorization). |

### @GraphQL

Use it to make the model a type of the API. All other annotations on this page need it.

```dart
@GraphQL()
```

It also has `filter:`, which hides the rows that a user cannot read. See [Hide rows](#hide-rows).

### @GraphQLAll

Use it when a client must read a list with `limit` and `offset`. The default `limit` is `20`, and the maximum is `100`.

```dart
@GraphQLAll()
```

```graphql
{ posts(limit: 10, offset: 20) { title } }
```

### @GraphQLPaginate

Use it when a client shows pages and needs the total number of rows. See [Pagination](#pagination).

```dart
@GraphQLPaginate()
```

```graphql
{ posts(first: 10, page: 2) { data { title } paginatorInfo { total } } }
```

### @GraphQLFind

Use it when a client must read one row by its id. The result is `null` if no row has that id.

```dart
@GraphQLFind()
```

```graphql
{ post(id: 1) { title } }
```

### @GraphQLCreate

Use it to let a client add a row. The `dto:` class has the fields that the client can set. See [Create](#create).

```dart
@GraphQLCreate(dto: PostInput)
```

```graphql
mutation { createPost(input: { title: "My second post" }) { id } }
```

### @GraphQLUpdate

Use it to let a client change a row. It changes only the fields that the client sends. See [Update](#update).

```dart
@GraphQLUpdate(dto: PostInput)
```

```graphql
mutation { updatePost(id: 1, input: { title: "A better title" }) { title } }
```

### @GraphQLDelete

Use it to let a client remove a row. The result is `true`, or `false` if no row has that id. See [Delete](#delete).

```dart
@GraphQLDelete()
```

```graphql
mutation { deletePost(id: 1) }
```

## Pagination

Use `@GraphQLPaginate()` for a list with page numbers. The client sends `first` (the number of rows on a page) and `page`:

```graphql
{
  posts(first: 10, page: 2) {
    data {
      title
    }
    paginatorInfo {
      total
      currentPage
      lastPage
      hasMorePages
    }
  }
}
```

```json
{
  "data": {
    "posts": {
      "data": [{ "title": "Hello GraphQL" }],
      "paginatorInfo": { "total": 11, "currentPage": 2, "lastPage": 2, "hasMorePages": false }
    }
  }
}
```

The default `first` is `20`, and the maximum is `100`. The default `page` is `1`.

`data` has the rows of the page. `paginatorInfo` has these fields:

| Field | Value |
|---|---|
| `total` | The number of rows on all pages. |
| `count` | The number of rows on this page. |
| `perPage` | The value of `first`. |
| `currentPage` | The number of this page. |
| `lastPage` | The number of the last page. |
| `hasMorePages` | `true` if there is a page after this page. |
| `firstItem` | The number of the first row of this page. The first row of page 1 is `1`. `null` on an empty page. |
| `lastItem` | The number of the last row of this page. `null` on an empty page. |

If the model has `@GraphQLAll()` and `@GraphQLPaginate()`, the list is `posts` and the paged list is `postsPaginate`. To set a different name, use `name:`:

```dart
@GraphQLPaginate(name: 'postPages')
```

## Write your own query

Write your own query when the queries of the annotations are not sufficient, for example for a search or a top-ten list. Put `@GraphQLQuery()` on a method of a class in `lib/`. This method is a **resolver**. A resolver is your code that gives the result of the query.

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

A **mutation** is a request that changes data. Dox makes the create, update, and delete mutations of a model from `@GraphQLCreate`, `@GraphQLUpdate` and `@GraphQLDelete`.

### Create

Write a [DTO](../the-basic/dto.md) with the fields that a client can set:

```dart title="lib/app/dtos/post_input/post_input.dto.dart"
import 'package:dox_core/dox_core.dart';

part 'post_input.dto.g.dart';

@Dto()
class PostInput {
  PostInput({required this.title});

  @MinLength(3, message: 'The title is too short')
  final String title;
}
```

Give the DTO to `@GraphQLCreate`. Then run the builder:

```dart title="lib/app/models/post/post.model.dart"
@DoxModel()
@GraphQL()
@GraphQLCreate(dto: PostInput)
class Post extends PostGenerator {}
```

The API now has `createPost`:

```graphql
mutation {
  createPost(input: { title: "My second post" }) { id title }
}
```

A client can set only the fields of the DTO. Thus, a client cannot set a different column, for example `userId`.

Dox applies the rules of the DTO before it saves the post. If the input is not correct, Dox saves nothing. The client gets the error `VALIDATION_FAILED`, with the message for each field in `extensions.fields`.

### Set the owner of a new row

Use `owner:` when each row belongs to the user that made it. Dox sets that column to the id of the logged-in user. Thus, a client must log in to create a post.

```dart
@GraphQLCreate(dto: PostInput, owner: 'userId')
```

The owner column must not be a field of the DTO. `updatePost` never changes it. `owner:` needs `AuthMiddleware()` in the config. See [Authentication](#authentication).

### Update

Give a DTO to `@GraphQLUpdate`. It can be the same DTO as for create:

```dart
@GraphQLUpdate(dto: PostInput, can: Ability.update, guard: true)
```

`updatePost` changes only the fields that the client sends. Dox applies only the rules of those fields. The result is `null` if no row has the id.

Without `can:`, each client that can call `updatePost` can change each row. The builder shows a warning if `@GraphQLUpdate` has no `can:` and no `guard:`. See [update](#update_1).

### Delete

`@GraphQLDelete` needs no DTO:

```dart
@GraphQLDelete(can: Ability.delete, guard: true)
```

Without `can:`, each client that can call `deletePost` can delete each row. The builder shows a warning if `@GraphQLDelete` has no `can:` and no `guard:`. See [delete](#delete_1).

### Write your own mutation

Write your own mutation when one saved row is not sufficient. Put `@GraphQLMutation()` on a resolver method, and use a DTO for the input. Dox applies the rules of the DTO before your method runs.

```dart title="lib/app/graphql/post.resolver.dart"
@GraphQLMutation()
Future<Post> importPost(PostInput input) {
  return postService.import(input);
}
```

## Authentication

By default, all clients can call all queries and mutations. To make clients log in, use `AuthMiddleware` from `dox_auth` and `guard: true`. If your app does not have a login, set it up first with [`dox add auth`](../security/authentication.md).

Add `AuthMiddleware()` to the config. Dox uses it to read the user:

```dart title="lib/config/graphql.dart"
import 'package:dox_auth/dox_auth.dart';
import 'package:dox_graphql/dox_graphql.dart';
import 'package:my_app/generated/schema.g.dart';

GraphQLConfig graphqlConfig = GraphQLConfig(
  schema: graphqlSchema,
  middleware: <Object>[AuthMiddleware()],
);
```

The middleware does not stop a request. All fields stay public until you add `guard: true`. The client sends its token in the `Authorization: Bearer <token>` header, as usual.

### Make a query or mutation need a login

Set `guard: true` on the annotation of each operation that a guest must not use:

```dart title="lib/app/models/post/post.model.dart"
@DoxModel()
@GraphQL()
@GraphQLAll()
@GraphQLFind()
@GraphQLCreate(dto: PostInput, guard: true)
@GraphQLUpdate(dto: PostInput, guard: true)
@GraphQLDelete(guard: true)
class Post extends PostGenerator {}
```

Here, a guest can read posts, but only a logged-in user can change them.

`guard: true` works the same on `@GraphQLQuery`, `@GraphQLMutation`, `@GraphQLField` and `@GraphQLResolveField`:

```dart title="lib/app/graphql/post.resolver.dart"
@GraphQLQuery(guard: true)
Future<List<Post>> trendingPosts({int limit = 10}) {
  return postService.trending(limit);
}
```

If a guest asks for a guarded field, the guest gets the error `UNAUTHENTICATED` for that field. The other fields in the same request still give their data. To make this possible, each query, each mutation and each relation can be `null` in the schema.

`guard: true` needs `AuthMiddleware()` in the config. If the config does not have it, the app stops at start and shows the name of the type or field.

### Protect a model everywhere

Write `@GraphQL(guard: true)` on a model that a guest must never see, for example `User`. Then each field that gives a user needs a login: its queries, its mutations, each relation such as `post.user`, and your own resolvers.

```dart title="lib/app/models/user/user.model.dart"
@DoxModel()
@GraphQL(guard: true)
@GraphQLFind()
class User extends UserGenerator {}
```

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

`guard: true` is only a login check. Use `can:` and `filter:` with a policy when the answer is different for each user or each row.

### Write a policy

A policy is a class with one method for each rule. The `abilities` map gives a name to each method. This name is the **ability**. `Ability` of `dox_auth` has the usual names: `viewAny`, `view`, `create`, `update` and `delete`.

```dart title="lib/app/policies/post_policy.dart"
import 'package:dox_auth/dox_auth.dart';
import 'package:my_app/app/models/post/post.model.dart';
import 'package:my_app/app/models/user/user.model.dart';

class PostPolicy extends Policy<User, Post> {
  bool update(User user, Post post) => post.userId == user.id;

  @override
  Map<String, Function> get abilities => <String, Function>{
    Ability.update: update,
  };
}
```

Each section below adds one method to this policy. Add each new method to `abilities` also. To learn more about policies, read [Writing policies](../security/authorization.md#writing-policies).

### Register the policy

Register the policy in the `setup()` of a provider. `dox add graphql` made the GraphQL provider, so you can use it. Keep the `super.setup()` call:

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

The config must have `AuthMiddleware()`. Without it, Dox cannot read the user, and each client is a guest.

### Use it on a model

Give an ability to an operation with `can:`. Dox asks the policy before the operation runs:

```dart title="lib/app/models/post/post.model.dart"
import 'package:dox_auth/dox_auth.dart';

@DoxModel()
@GraphQL(filter: Ability.view)
@GraphQLAll(can: Ability.viewAny)
@GraphQLPaginate(can: Ability.viewAny)
@GraphQLFind(can: Ability.view)
@GraphQLCreate(dto: PostInput, can: Ability.create, guard: true, owner: 'userId')
@GraphQLUpdate(dto: PostInput, can: Ability.update, guard: true)
@GraphQLDelete(can: Ability.delete, guard: true)
class Post extends PostGenerator {
  @Column()
  String? title;

  @Column()
  String? status;

  @Column()
  int? userId;
}
```

An operation with no `can:` does not ask the policy. Use only the checks that the model needs.

| Annotation | The policy method gets |
|---|---|
| `@GraphQLAll(can:)`, `@GraphQLPaginate(can:)`, `@GraphQLCreate(can:)` | The user. |
| `@GraphQLFind(can:)`, `@GraphQLUpdate(can:)`, `@GraphQLDelete(can:)` | The user and the row. |
| `@GraphQL(filter:)` | The user and each row. |

The first group gets no row. Thus, use `Ability.viewAny` on `@GraphQLAll` and `@GraphQLPaginate`, and `Ability.create` on `@GraphQLCreate`. Do not use `Ability.view` or `Ability.update` there.

### viewAny

Use `viewAny` when some users must not get lists of the model. Put it on `@GraphQLAll` and `@GraphQLPaginate`:

```dart
@GraphQLAll(can: Ability.viewAny)
```

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

Use `view` when a user can read some rows and not others. Put it on `@GraphQLFind`:

```dart
@GraphQLFind(can: Ability.view)
```

Here, a user can read a published post and their own posts:

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

### Hide rows

Use `filter:` on `@GraphQL` when a client must get only the rows that the user can read:

```dart
@GraphQL(filter: Ability.view)
```

Dox hides each row that the ability refuses, and gives no error. This applies to each field that gives the model:

- The `posts` list and the paged list. Thus, a list can have fewer rows than `limit`.
- A list relation, for example `user.posts`.
- A single relation, for example `comment.post`. A refused row is `null`.
- The `post(id)` query. A refused row is `null`, the same as an id that does not exist.
- Your own queries, mutations and fields that return the model.
- The result of `updatePost`. The row is saved, but the result is `null`.

In a paged list, `total` and `lastPage` also count the hidden rows.

The result of `createPost` is not filtered: the client gets back the row it sent.

`filter:` does not decide who can change a row. `updatePost` and `deletePost` ask only their `can:`, so a user can change a hidden row when they have no `can:`. Give them a `can:`.

A field can give a filtered model as `Post`, `Post?`, `List<Post>` or `List<Post>?`. Other shapes, like `List<List<Post>>` or `List<Post?>`, stop the build.

To get `null` and no error from `post(id)`, use `filter:` and no `can:` on `@GraphQLFind`. With `can:`, a refused user gets `FORBIDDEN`.

### create

Use `create` when only some users can add a row. The method gets only the user, because no row exists yet:

```dart
@GraphQLCreate(dto: PostInput, can: Ability.create)
```

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

Use `update` to decide who can change a row:

```dart
@GraphQLUpdate(dto: PostInput, can: Ability.update)
```

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

Use `delete` to decide who can remove a row:

```dart
@GraphQLDelete(can: Ability.delete)
```

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

### Add your own ability

Use your own ability when the five names of `Ability` are not sufficient. Write the name as a constant on the policy:

```dart title="lib/app/policies/post_policy.dart"
class PostPolicy extends Policy<User, Post> {
  static const String publish = 'publish';

  bool canPublish(User user, Post post) => user.editor == true;

  @override
  Map<String, Function> get abilities => <String, Function>{
    publish: canPublish,
  };
}
```

```dart
@GraphQLUpdate(dto: PostInput, can: PostPolicy.publish)
```

### Fix an ability that the policy does not have

When the app starts, Dox makes sure that the policy has each ability of `can:` and `filter:`. If one is missing, the app stops with an error that shows the available abilities:

```text
@GraphQLDelete(can: 'delete') on Post: PostPolicy has no ability 'delete'. Available: update.
```

Add the ability to the `abilities` map of the policy. If the error says that the model has no policy, register the policy in the `setup()` of a provider.

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
  Map<String, Function> get abilities => <String, Function>{Ability.view: view};
}
```

Now a guest can read the published posts, and a user can also read their own drafts.

To refuse guests on one operation of this model, add `guard: true` to that operation.

### Your own resolvers

`filter:` also hides rows in the result of your own `@GraphQLQuery`, `@GraphQLMutation`, `@GraphQLResolveField` or getter. `can:` works only on the operations of the model annotations. To refuse a user with an error in your own resolver, call [`Gate`](../security/authorization.md#checking-a-gate) yourself:

```dart title="lib/app/graphql/post.resolver.dart"
@GraphQLQuery()
Future<Post?> latestPost(DoxGraphQLContext context) async {
  Post? post = await postService.latest();
  User? user = await context.user<User>();
  if (post != null && await Gate.denies(user, Ability.view, post)) {
    throw GraphQLAuth.forbidden();
  }
  return post;
}
```

`GraphQLAuth.forbidden()` gives the same `FORBIDDEN` error as `can:`.

## Configuration

All settings are fields of `GraphQLConfig` in `lib/config/graphql.dart`, for example `path: '/api/graphql'`. Each setting in the table has a default. Set only the settings that you want to change.

| Setting | Default | What it does |
|---|---|---|
| `path` | `/graphql` | The URL of the API. |
| `middleware` | none | Route middleware, like `AuthMiddleware()`. |
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

If your app does not use models, install with `dox add graphql --no-orm`. Put `@GraphQL()` on a plain Dart class. Its public fields are the fields that a client can ask for. You write all the queries yourself:

```dart title="lib/app/graphql/product.resolver.dart"
import 'package:dox_graphql/dox_graphql.dart';
import 'package:my_app/app/repositories/product.repository.dart';
import 'package:my_app/app/repositories/shop.repository.dart';

@GraphQL()
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

  @GraphQLResolveField()
  Future<Shop?> shop(Product product, DoxGraphQLContext context) {
    DataLoader<int, Shop> shops = context.loader<int, Shop>(
      'shops',
      () => DataLoader<int, Shop>(shopRepository.findByIds),
    );
    return shops.load(product.shopId);
  }
}
```

`@GraphQLResolveField()` adds a field to the class of its first parameter. Thus, `Product` gets a `shop` field, and `Shop` also needs `@GraphQL()`.

The `DataLoader` collects the shop ids of the full request. Thus, fifty products cause one shop query, not fifty queries. `findByIds` takes a `List<int>` and returns a `Future<List<Shop?>>`, in the same order as the ids.
