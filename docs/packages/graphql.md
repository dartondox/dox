---
icon: simple/graphql
---

# GraphQL

`dox_graphql` gives your app a GraphQL API, made from your models.

GraphQL is an API with one URL. The client writes the fields it wants, and it gets JSON with only those fields. One request can read a post, its user and its comments together. To learn GraphQL itself, read [graphql.org/learn](https://graphql.org/learn/).

## Quick start

### Install

```bash
dox add graphql
```

It adds the packages, `lib/config/graphql.dart` and `lib/providers/graphql_provider.dart`. It never overwrites a file.

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

The `id`, the columns and the relations of the model are now fields a client can ask for. `Post` has a relation to `User`, so put `@GraphQLType()` on `User` too.

Then run the builder and start the app again. Do this after every change on this page:

```bash
dart run build_runner build
```

### Run a query

A **query** is a request that reads data. Each model gets two queries for free. For `Post` they are:

- `posts(limit, offset)`: a list of posts. `limit` is `20` by default and can be at most `100`.
- `post(id)`: one post, or `null` when no post has that id.

Open `http://localhost:3000/graphql` in a browser. In development this shows GraphiQL, a page where you write and run queries. Run this one:

```graphql
{
  posts(limit: 10) {
    title
    user { name }
  }
}
```

The answer has the same shape as the query:

```json
{ "data": { "posts": [{ "title": "Hello GraphQL", "user": { "name": "Ada" } }] } }
```

Dox loads the users of all ten posts with one database query.

Your own client sends the same query as a `POST` request to `/graphql`, with the JSON body `{"query": "..."}`.

### Hide a field

A client must not see some columns. Fields in `hidden` of the model are already left out, so a password never shows. To hide another field, put `@GraphQLIgnore()` on the line above its `@Column()`.

### Turn off the free queries

Sometimes a model must be reachable only through a relation, like `post.user`. Then write `@GraphQLType(queries: false)` on it, and it gets no queries of its own.

To turn off the free queries and mutations of all models, set `autoResolvers: false` in the [configuration](#configuration).

## Your own query

Write your own query when the free ones are not enough, for example a search or a top ten. Put `@GraphQLQuery()` on a method of any class in `lib/`. This method is called a **resolver**: it is your code that answers the query.

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

Run the builder and start the app again. The builder finds the class by itself. Dox reads the rest from the method:

- The method name is the query name: `trendingPosts`.
- The parameters are the values a client can send. A parameter with a default value is optional.
- The return type says what the client gets back.
- The constructor parameters come from the [container](../the-basic/dependency-injection.md).

A client calls it like this: `{ trendingPosts(limit: 3) { title } }`.

### Send an error to the client

Throw a `GraphQLError` to send your own message, like `throw GraphQLError('This post is not published yet');`.

For any other error, the client sees "Internal server error" in production. The real error goes to the `ExceptionHandler` of your app.

## Create, update and delete

A **mutation** is a request that changes data. Dox can make the create, update and delete mutations of a model for you.

### Create

Write a [DTO](../the-basic/dto.md) with the fields a client may set:

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

Give it to the model with `dto:`, then run the builder:

```dart title="lib/app/models/post/post.model.dart"
@DoxModel()
@GraphQLType(dto: CreatePostDto)
class Post extends PostGenerator {}
```

Now the API has `createPost`:

```graphql
mutation {
  createPost(input: { title: "My second post" }) { id title }
}
```

A client can set only the fields of the DTO. So it can never set another column, like `userId`.

The rules of the DTO run before the post is saved. When the input is wrong, nothing is saved. The client gets the error `VALIDATION_FAILED`, with the message of each field in `extensions.fields`.

### Update and delete

Update and delete change a row that already exists, so Dox must know who may change it. You say this with a policy. See [Authorization](#authorization) below.

### Your own mutation

Write your own mutation when saving one row is not enough. Put `@GraphQLMutation()` on a resolver method, and take the input as a DTO. The rules of the DTO run before your method.

```dart title="lib/app/graphql/post.resolver.dart"
@GraphQLMutation()
Future<Post> importPost(CreatePostDto input) {
  return postService.import(input);
}
```

## Authentication

At the start, everyone can call everything. To ask for a login, use `AuthMiddleware` from `dox_auth`. If your app has no login yet, set it up first with [`dox add auth`](../security/authentication.md).

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

Now every query, every mutation and every relation (like `post.user`) needs a logged-in user. The client sends its token as usual, in the `Authorization: Bearer <token>` header.

A guest who asks for a protected field gets the error `UNAUTHENTICATED` for that field. Public fields in the same request still give their data. The GraphiQL page stays open in development, but it shows no data to a guest.

### Make a field public

Set `auth: false` on the fields a guest may use:

```dart title="lib/app/graphql/post.resolver.dart"
@GraphQLQuery(auth: false)
Future<List<Post>> trendingPosts({int limit = 10}) {
  return postService.trending(limit);
}
```

It works the same on `@GraphQLMutation`.

On a model, `@GraphQLType(auth: false)` makes the model public everywhere: its free queries and mutations, and every relation that gives it.

A public query does not open the relations inside it. When `trendingPosts` is public, a guest gets the `title` of each post, but `user` inside a post still needs a login. To open it, `User` needs `auth: false` too.

### Protect a model everywhere

Write `@GraphQLType(auth: true)` on a model that a guest must never see, like `User`. Then every field that gives a user needs a login, even inside a public query.

`auth: true` needs `AuthMiddleware()` in the config. Without it, the app stops at start and names the type or field.

### Read the logged-in user

Add a `DoxGraphQLContext` parameter to a resolver method. It is not a value the client sends. Dox fills it with the current request:

```dart title="lib/app/graphql/user.resolver.dart"
@GraphQLQuery()
Future<User?> me(DoxGraphQLContext context) {
  return context.user<User>();
}
```

`context.user<User>()` gives `null` for a guest.

## Authorization

Authentication asks "who are you". Authorization asks "may you change this row". For update and delete, you answer with a [policy](../security/authorization.md#writing-policies) that has an `update` and a `delete` method:

```dart title="lib/app/policies/post_policy.dart"
import 'package:dox_auth/dox_auth.dart';
import 'package:my_app/app/models/post/post.model.dart';
import 'package:my_app/app/models/user/user.model.dart';

class PostPolicy extends Policy<User, Post> {
  bool update(User user, Post post) => post.userId == user.id;
  bool delete(User user, Post post) => post.userId == user.id;

  @override
  Map<String, Function> get abilities => <String, Function>{
    'update': update,
    'delete': delete,
  };
}
```

Register it with `Gate.policy<Post>(PostPolicy());` in the [`setup()` of a provider](../security/authorization.md#registering-the-rules). Then give it to the model with `policy:`, next to `dto:`, and run the builder:

```dart title="lib/app/models/post/post.model.dart"
@DoxModel()
@GraphQLType(dto: CreatePostDto, policy: PostPolicy)
class Post extends PostGenerator {}
```

Now the API has `updatePost` and `deletePost`:

```graphql
mutation {
  updatePost(id: 1, input: { title: "A better title" }) { title }
  deletePost(id: 2)
}
```

For each call, Dox loads the row and asks the policy. When the policy says no, nothing is written and the client gets the error `FORBIDDEN`. A guest can never update or delete, because the policy needs a user.

`updatePost` changes only the fields the client sends, and checks only the rules of those fields.

## Configuration

All settings are fields of `GraphQLConfig` in `lib/config/graphql.dart`, like `path: '/api/graphql'`. Every setting in the table has a default, so you only set the ones you want to change.

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

"On in development" means on when `APP_ENV` is `development`. So in production GraphiQL is off, nobody can list your fields, and error details stay on the server. You change nothing for this.

The three `max` settings stop a very big query before it costs your server much work. Lower them when your API is open to the public.

## Without the ORM

If your app does not use models, install with `dox add graphql --no-orm`. Put `@GraphQLType()` on a plain Dart class. Its public fields are the fields a client can ask for. You write every query yourself:

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

`@ResolveField()` adds a field to the class of its first parameter. So `Product` gets a `shop` field, and `Shop` needs `@GraphQLType()` too. The `DataLoader` collects the shop ids of the whole request, so fifty products run one shop query and not fifty. `findByIds` takes a `List<int>` and returns a `Future<List<Shop?>>`, in the same order as the ids.
