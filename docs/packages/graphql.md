---
icon: simple/graphql
---

# GraphQL

GraphQL makes an API for your app from your models. You add annotations to a model, run the builder, and the API is ready.

A GraphQL API has one URL. The client writes the fields that it wants, and it gets JSON with only those fields. To learn GraphQL, read [graphql.org/learn](https://graphql.org/learn/).

## Install

Run the setup command in your app:

```bash
dox add graphql
```

The command adds the packages, `lib/config/graphql.dart` and `lib/providers/graphql_provider.dart`. It does not overwrite a file. For an app with no models, see [Without the ORM](#without-the-orm).

## Add a model to the API

Put `@GraphQL()` on a model. Then add one annotation for each operation that a client can use:

```dart title="lib/app/models/post/post.model.dart"
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

`@GraphQLAll()` adds the `posts` query, and `@GraphQLFind()` adds the `post` query. An operation with no annotation does not exist.

The `id`, the columns and the relations of the model are fields that a client can ask for. `Post` has a relation to `User`, so put `@GraphQL()` on `User` also.

Run the builder, and start the app again. Do these two steps after each change to an annotation:

```bash
dart run build_runner build
```

## Run a query

A query is a request that reads data. In development, open `http://localhost:3000/graphql` in a browser. This URL shows GraphiQL, a page where you write and run queries:

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

## All operations

Each annotation adds one query or one mutation. A mutation is a request that changes data.

| Annotation | GraphQL field | Function |
|---|---|---|
| `@GraphQLAll()` | `posts(limit, offset)` | Reads a list. |
| `@GraphQLPaginate()` | `posts(first, page)` | Reads a page of a list, with the total number of rows. |
| `@GraphQLFind()` | `post(id)` | Reads one row. |
| `@GraphQLCreate(dto:)` | `createPost(input)` | Adds a row. |
| `@GraphQLUpdate(dto:)` | `updatePost(id, input)` | Changes a row. |
| `@GraphQLDelete()` | `deletePost(id)` | Removes a row. |

Create and update use a [DTO](../the-basic/dto.md), so the input gets the same validation as your HTTP routes. For each annotation, see [Model annotations](#model-annotations).

## Write your own query

Write your own query when the annotations are not sufficient, for example for a search. Put `@GraphQLQuery()` on a method of a class in `lib/`:

```dart title="lib/app/graphql/post.resolver.dart"
class PostResolver {
  @GraphQLQuery()
  Future<List<Post>> latestPosts({int limit = 10}) {
    return Post().orderBy('id', 'desc').limit(limit).get();
  }
}
```

The method name is the query name, and the parameters are the values that a client can send:

```graphql
{ latestPosts(limit: 3) { title } }
```

For more, see [Your own resolvers](#your-own-resolvers).

## Protect the API

By default, all clients can use all operations. Set `guard: true` on an operation that a guest must not use. Give an ability with `can:`, and Dox asks the [policy](../security/authorization.md#writing-policies) of the model before the operation runs:

```dart title="lib/app/models/post/post.model.dart"
@DoxModel()
@GraphQL(filter: Ability.view)
@GraphQLAll(can: Ability.viewAny)
@GraphQLFind(can: Ability.view)
@GraphQLCreate(dto: PostInput, can: Ability.create, guard: true, owner: 'userId')
@GraphQLUpdate(dto: PostInput, can: Ability.update, guard: true)
@GraphQLDelete(can: Ability.delete, guard: true)
class Post extends PostGenerator {}
```

- `guard: true` makes the operation need a login.
- `can:` asks the policy if the user can do the operation.
- `filter:` hides the rows that the user cannot read.
- `owner: 'userId'` sets the owner of a new row to the logged-in user.

A guest that Dox refuses gets the error `UNAUTHENTICATED`. A user that Dox refuses gets the error `FORBIDDEN`. The other fields of the request still give their data.

To set this up, see [Authentication](#authentication) and [Authorization](#authorization).

## Production defaults and limits

In production, GraphiQL and introspection are off, and error details stay on the server. You do not set anything for this.

Limits stop a very large query before it causes much work on your server. For example, a query can nest 64 levels, and a list gives a maximum of 100 rows. Set lower limits when your API is open to the public:

```dart title="lib/config/graphql.dart"
GraphQLConfig graphqlConfig = GraphQLConfig(
  schema: graphqlSchema,
  maxDepth: 10,
  maxNodes: 10000,
);
```

For all settings, see [Configuration](#configuration).

## Model annotations

Each annotation can have these options:

| Option | Function |
|---|---|
| `name:` | A different name for the type or the field. |
| `description:` | The text that GraphiQL shows. |
| `guard: true` | A client must log in. See [Authentication](#authentication). |
| `can:` | The policy must allow the user. `@GraphQL` does not have this option. See [Authorization](#authorization). |

### @GraphQL

Use it to make the model a type of the API. All other model annotations need it.

```dart
@GraphQL()
```

A model with only `@GraphQL()` has no queries and no mutations. A client gets it only through a relation, for example `post.user`.

Dox does not show the fields in the `hidden` list of the model, so a password stays on the server. To hide a different field, put `@GraphQLIgnore()` above its `@Column()`.

`@GraphQL` also has `filter:`. See [Hide rows](#hide-rows).

### @GraphQLAll

Use it when a client must read a list with `limit` and `offset`:

```dart
@GraphQLAll()
```

```graphql
{ posts(limit: 10, offset: 20) { title } }
```

The default `limit` is `20`. A `limit` of more than `100` gives an error.

### @GraphQLPaginate

Use it when a client shows pages and needs the total number of rows. The client sends `first`, which is the number of rows on a page, and `page`:

```dart
@GraphQLPaginate()
```

```graphql
{
  posts(first: 10, page: 2) {
    data { title }
    paginatorInfo { total currentPage lastPage hasMorePages }
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

The default `first` is `20`, and the default `page` is `1`. A `first` of more than `100` gives an error.

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

If the model also has `@GraphQLAll()`, the list is `posts` and the paged list is `postsPaginate`. To set a different name, use `name:`:

```dart
@GraphQLPaginate(name: 'postPages')
```

### @GraphQLFind

Use it when a client must read one row by its id:

```dart
@GraphQLFind()
```

```graphql
{ post(id: 1) { title } }
```

The result is `null` if no row has that id.

### @GraphQLCreate

Use it to let a client add a row. First, write a [DTO](../the-basic/dto.md) with the fields that the client can set:

```dart title="lib/app/dtos/post_input/post_input.dto.dart"
@Dto()
class PostInput {
  PostInput({required this.title});

  @MinLength(3, message: 'The title is too short')
  final String title;
}
```

Then give the DTO to the annotation:

```dart
@GraphQLCreate(dto: PostInput)
```

```graphql
mutation {
  createPost(input: { title: "My second post" }) { id title }
}
```

A client can set only the fields of the DTO. Thus, a client cannot set a different column, for example `userId`.

Dox applies the rules of the DTO before it saves the row. If the input is not correct, Dox saves nothing. The client gets the error `VALIDATION_FAILED`, with the message for each field in `extensions.fields`.

### Set the owner of a new row

Use `owner:` when each row belongs to the user that made it. Dox sets that column to the id of the logged-in user:

```dart
@GraphQLCreate(dto: PostInput, owner: 'userId')
```

With `owner:`, the client must log in to create a row. The owner column must not be a field of the DTO. An update never changes the owner column.

### @GraphQLUpdate

Use it to let a client change a row. It can use the same DTO as `@GraphQLCreate`:

```dart
@GraphQLUpdate(dto: PostInput, can: Ability.update, guard: true)
```

```graphql
mutation { updatePost(id: 1, input: { title: "A better title" }) { title } }
```

`updatePost` changes only the fields that the client sends, and Dox applies only the rules of those fields. The result is `null` if no row has that id.

!!! warning

    Without `can:`, each client that can call `updatePost` or `deletePost` can change or delete each row. Add `can:` to `@GraphQLUpdate` and `@GraphQLDelete`. The builder shows a warning if one of them has no `can:` and no `guard:`.

### @GraphQLDelete

Use it to let a client remove a row. It needs no DTO:

```dart
@GraphQLDelete(can: Ability.delete, guard: true)
```

```graphql
mutation { deletePost(id: 1) }
```

The result is `true`, or `false` if no row has that id.

## Authentication

Use `guard: true` when a client must log in. If your app does not have a login, set it up first with [`dox add auth`](../security/authentication.md).

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

Set `guard: true` on each operation that a guest must not use:

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

If a guest asks for a guarded field, the guest gets the error `UNAUTHENTICATED` for that field. The other fields in the same request still give their data.

`guard: true` needs `AuthMiddleware()` in the config. Without it, the app stops at start and shows the name of the type or field.

### Protect a model everywhere

Write `@GraphQL(guard: true)` on a model that a guest must never see, for example `User`:

```dart title="lib/app/models/user/user.model.dart"
@DoxModel()
@GraphQL(guard: true)
@GraphQLFind()
class User extends UserGenerator {}
```

Then each field that gives a user needs a login. This includes its queries, its mutations, each relation such as `post.user`, and your own resolvers.

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

`guard: true` is only a login check. Use a [policy](../security/authorization.md#writing-policies) when the answer is different for each user or each row.

### Write a policy

A policy is a class with one method for each rule. The `abilities` map gives a name to each method. This name is the ability. `Ability` has the usual names: `viewAny`, `view`, `create`, `update` and `delete`.

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

Each ability section below adds one method to this policy. Add each new method to `abilities` also.

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

When the app starts, Dox makes sure that the policy has each ability of `can:` and `filter:`. If one is missing, the app stops with an error that shows the available abilities:

```text
@GraphQLDelete(can: 'delete') on Post: PostPolicy has no ability 'delete'. Available: update.
```

### Use it on a model

Give an ability to an operation with `can:`. Dox asks the policy before the operation runs. An operation with no `can:` does not ask the policy.

```dart title="lib/app/models/post/post.model.dart"
@DoxModel()
@GraphQL(filter: Ability.view)
@GraphQLAll(can: Ability.viewAny)
@GraphQLPaginate(can: Ability.viewAny)
@GraphQLFind(can: Ability.view)
@GraphQLCreate(dto: PostInput, can: Ability.create, guard: true, owner: 'userId')
@GraphQLUpdate(dto: PostInput, can: Ability.update, guard: true)
@GraphQLDelete(can: Ability.delete, guard: true)
class Post extends PostGenerator {}
```

Some policy methods get a row, and some do not:

| Annotation | The policy method gets | Use |
|---|---|---|
| `@GraphQLAll(can:)`, `@GraphQLPaginate(can:)` | The user. | `Ability.viewAny` |
| `@GraphQLCreate(can:)` | The user. | `Ability.create` |
| `@GraphQLFind(can:)` | The user and the row. | `Ability.view` |
| `@GraphQLUpdate(can:)` | The user and the row. | `Ability.update` |
| `@GraphQLDelete(can:)` | The user and the row. | `Ability.delete` |
| `@GraphQL(filter:)` | The user and each row. | `Ability.view` |

Do not use an ability that needs a row, like `Ability.view`, on `@GraphQLAll`, `@GraphQLPaginate` or `@GraphQLCreate`.

When the policy refuses a user, the field is `null`. The other fields keep their data:

```json
{ "data": { "posts": null, "me": { "name": "Ada" } } }
```

The `errors` list of the result has one error for `posts`. Its code is `FORBIDDEN`, in `extensions.code`.

### viewAny

Use `viewAny` when some users must not get lists of the model:

```dart
@GraphQLAll(can: Ability.viewAny)
```

```dart
bool viewAny(User user) => user.banned != true;
```

### view

Use `view` when a user can read some rows and not others. Here, a user can read a published post and their own posts:

```dart
@GraphQLFind(can: Ability.view)
```

```dart
bool view(User user, Post post) {
  return post.status == 'published' || post.userId == user.id;
}
```

A refused user gets `FORBIDDEN` from `post(id)`.

### Hide rows

Use `filter:` on `@GraphQL` when a client must get only the rows that the user can read:

```dart
@GraphQL(filter: Ability.view)
```

Dox hides each row that the ability refuses, and gives no error. This applies to each field that gives the model:

- A list, a paged list, or a list relation such as `user.posts` does not include the row. Thus, a list can have fewer rows than `limit`.
- `post(id)` or a single relation such as `comment.post` gives `null`.
- Your own queries, mutations and fields that return the model do the same.

!!! warning

    `filter:` does not decide who can change a row. `updatePost` and `deletePost` ask only their `can:`. Give them a `can:`.

To get `null` and no error from `post(id)`, use `filter:` and no `can:` on `@GraphQLFind`.

### create

Use `create` when only some users can add a row. The method gets only the user, because no row exists yet:

```dart
@GraphQLCreate(dto: PostInput, can: Ability.create)
```

```dart
bool create(User user) => user.verified == true;
```

Dox asks the policy first. It applies the rules of the DTO only for a user that the policy allows. For a refused user, Dox saves nothing.

### update

Use `update` to decide who can change a row:

```dart
@GraphQLUpdate(dto: PostInput, can: Ability.update)
```

```dart
bool update(User user, Post post) => post.userId == user.id;
```

For a refused user, Dox writes nothing.

### delete

Use `delete` to decide who can remove a row:

```dart
@GraphQLDelete(can: Ability.delete)
```

```dart
bool delete(User user, Post post) => post.userId == user.id;
```

For a refused user, the row stays in the database.

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

### Let guests in

A guest is a client that is not logged in. With `Policy<User, Post>`, Dox refuses each guest with the error `UNAUTHENTICATED`.

Use `Policy<User?, Post>` when a guest can read some rows. Then a guest gets to your methods, and `user` is `null`:

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

Now a guest can read the published posts, and a user can also read their own drafts. To refuse guests on one operation of this model, add `guard: true` to that operation.

## Your own resolvers

A resolver is a method that gives the result of a query or a mutation. Write one when the model annotations are not sufficient. The builder finds each class in `lib/` that has a resolver method.

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

Dox gets the data of the query from the method:

- The method name is the query name: `trendingPosts`.
- The parameters are the values that a client can send. A parameter with a default value is optional.
- The return type is the type that the client gets.
- Dox gets the constructor parameters from the [container](../the-basic/dependency-injection.md).

A resolver annotation has `name:`, `description:` and `guard: true`, the same as a model annotation.

### Write your own mutation

Write your own mutation when one saved row is not sufficient. Put `@GraphQLMutation()` on a resolver method, and use a DTO for the input:

```dart title="lib/app/graphql/post.resolver.dart"
@GraphQLMutation()
Future<Post> importPost(PostInput input) {
  return postService.import(input);
}
```

Dox applies the rules of the DTO before your method runs.

### Send an error to the client

To send your own message, throw a `GraphQLError`:

```dart
throw GraphQLError('This post is not published yet');
```

For all other errors, the client sees "Internal server error" in production. Dox sends the real error to the `ExceptionHandler` of your app.

### Check a policy in a resolver

`can:` works only on the model annotations. To refuse a user in your own resolver, call [`Gate`](../security/authorization.md#checking-a-gate) yourself:

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

`GraphQLAuth.forbidden()` gives the same `FORBIDDEN` error as `can:`. `filter:` also hides rows in the result of your own resolvers.

## Configuration

All settings are fields of `GraphQLConfig` in `lib/config/graphql.dart`. Each setting has a default, so set only the settings that you want to change:

```dart title="lib/config/graphql.dart"
GraphQLConfig graphqlConfig = GraphQLConfig(
  schema: graphqlSchema,
  path: '/api/graphql',
);
```

| Setting | Default | What it does |
|---|---|---|
| `path` | `/graphql` | The URL of the API. |
| `middleware` | none | Route middleware, like `AuthMiddleware()`. |
| `graphiql` | on in development | The GraphiQL page. |
| `introspection` | on in development | Lets tools like GraphiQL read the list of your types and fields. |
| `showInternalErrors` | on in development | Sends the real text of an error to the client. |
| `maxDepth` | `64` | How deep a query can nest fields. |
| `maxQueryLength` | `1000000` | The most characters in the text of one query. |
| `maxFields` | `20000` | The most fields one query can ask for. |
| `maxNodes` | `100000` | The most values one request can load. |
| `maxRootFields` | `50` | The most top-level fields in one request. Each alias counts. |
| `maxRelationRows` | `50000` | The most rows that one list relation can load for all parent rows together. |

"On in development" means on when `APP_ENV` is `development`. For all other values, these three settings are off.

A request that is larger than a `max` setting gets an error. Set lower values when your API is open to the public.

## Without the ORM

If your app does not use models, install with `dox add graphql --no-orm`. Put `@GraphQL()` on a plain Dart class. Its public fields are the fields that a client can ask for. You write all the queries yourself:

```dart title="lib/app/graphql/product.resolver.dart"
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

## Performance

The same GraphQL API in Dox and in Go, on Postgres. The Dox app uses the ORM with `@GraphQLAll` and `@GraphQLFind`. The Go apps use gqlgen, one with pgx and one with GORM, and a dataloader for the relation.

<div class="dox-bench" markdown>

<p class="dox-bench__title">2 cores: 20 rows, each with its related rows</p>
<p class="dox-bench__sub"><code>{ worlds(limit: 20) { id randomNumber notes { id body } } }</code>, 256 connections. Requests per second, higher is better.</p>

<div class="dox-bench__grid">
  <span></span><span></span>
  <span class="dox-bench__head">req/s</span>
  <span class="dox-bench__head">p99</span>
  <span class="dox-bench__head dox-bench__head--ram">RAM</span>

  <div class="dox-bench__row dox-bench__row--win">
    <span class="dox-bench__name"><strong>Dox</strong><span>ORM</span></span>
    <span class="dox-bench__track"><span class="dox-bench__bar" style="--w: 100%"></span></span>
    <span class="dox-bench__num">5,990<span class="dox-bench__vs">fastest</span></span>
    <span class="dox-bench__p99">84 ms</span>
    <span class="dox-bench__ram">223 MB</span>
  </div>
  <div class="dox-bench__row">
    <span class="dox-bench__name"><strong>Go</strong><span>gqlgen + pgx</span></span>
    <span class="dox-bench__track"><span class="dox-bench__bar" style="--w: 65.4%"></span></span>
    <span class="dox-bench__num">3,918<span class="dox-bench__vs">1.5× slower</span></span>
    <span class="dox-bench__p99">79 ms</span>
    <span class="dox-bench__ram">132 MB</span>
  </div>
  <div class="dox-bench__row">
    <span class="dox-bench__name"><strong>Go</strong><span>gqlgen + GORM</span></span>
    <span class="dox-bench__track"><span class="dox-bench__bar" style="--w: 61.5%"></span></span>
    <span class="dox-bench__num">3,683<span class="dox-bench__vs">1.6× slower</span></span>
    <span class="dox-bench__p99">221 ms</span>
    <span class="dox-bench__ram">105 MB</span>
  </div>
</div>

<p class="dox-bench__foot"><span>Dox · Go 1.26 · gqlgen 0.17 · Postgres 18 · 2 cores · 256 connections · wrk</span></p>

</div>

All three queries at 256 connections, requests per second:

| Server               | One row by id | 20 rows | 20 rows with a relation | peak MB |
| -------------------- | ------------: | ------: | ----------------------: | ------: |
| Dox (ORM)            | 88,330        | 7,837   | 5,990                   | 223     |
| Go (gqlgen + pgx)    | 27,870        | 7,618   | 3,918                   | 132     |
| Go (gqlgen + GORM)   | 24,675        | 7,436   | 3,683                   | 105     |

- On one row by id, Dox is 3.2 times as fast as Go with pgx.
- On a list of 20 rows, all three are about the same. Postgres is the limit here.
- On a list with a relation, Dox is 1.5 times as fast.
- Dox uses more memory at the peak. After the load, its memory goes down again.

How it was run: the same rig as the [benchmark](../digging-deeper/performance.md#how-it-was-run) of the server. The server gets 2 CPUs, the database gets 2 CPUs and wrk gets the other 4. Each server has 8 database connections. Each query runs for 15 seconds, three times. The numbers are the median.

## Details

- **GET requests.** A client can also send a query as a `GET` request, with `query` in the URL. A mutation needs `POST`.
- **Computed fields.** Put `@GraphQLField()` on a getter of a `@GraphQL` class to make the getter a field. It has `guard: true` also.
- **Field types.** A field can be a `String`, `int`, `double`, `bool`, `DateTime`, an enum, a `@GraphQL` class, or a `List` of them. A different type stops the build. Put `@GraphQLIgnore()` on a field that the API does not need.
- **Paged lists with `filter:`.** `data` and `count` do not include the hidden rows. `total` and `lastPage` include them.
- **Results of mutations with `filter:`.** `createPost` always gives the new row. `updatePost` saves a hidden row, but its result is `null`.
- **Filtered types.** A field can give a model with `filter:` as `Post`, `Post?`, `List<Post>` or `List<Post>?`. A different shape stops the build.
- **An id that does not exist.** With `can:`, Dox asks the policy about an empty row. Thus, a refused user gets `FORBIDDEN` for each id. If your policy method allows an empty row, a client can find which ids exist.
- **Your own `AuthMiddleware`.** If you use a subclass of `AuthMiddleware`, override `asOptional()` to return your subclass. If you do not, your changes do not run.
