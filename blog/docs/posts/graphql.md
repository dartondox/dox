---
date:
  created: 2026-11-21
authors:
  - dox
categories:
  - Releases
tags:
  - release
  - graphql
slug: graphql
---

# GraphQL in Dox

The new `dox_graphql` package makes a GraphQL API for your app from your models. You add annotations to a model, run the builder, and the API is ready.

<!-- more -->

> **Key takeaways**
>
> - **An API from your models.** One annotation adds one query or one mutation. An operation with no annotation does not exist.
> - **No N+1 queries.** Dox loads a relation for all rows with one database query.
> - **Your policies protect the API.** `can:` asks the policy of the model before an operation runs. `guard: true` needs a login.
> - **Safe in production.** GraphiQL, introspection and error details are off in production. Limits stop very large queries.
> - **Made at build time.** The builder makes the schema from your models when you run `build_runner`.

## Install

Run the setup command in your app:

```bash
dox add graphql
```

The command adds the packages, `lib/config/graphql.dart` and the GraphQL provider. It does not overwrite a file. For an app with no models, use `dox add graphql --no-orm`.

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

`@GraphQLAll()` adds the `posts` query, and `@GraphQLFind()` adds the `post` query. The `id`, the columns and the relations of the model are fields that a client can ask for. The fields in the `hidden` list of the model are never visible, so a password stays on the server.

Run the builder:

```bash
dart run build_runner build
```

## Run a query

In development, open `http://localhost:3000/graphql` in a browser. This URL shows GraphiQL, a page where you write and run queries:

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

## All operations

| Annotation | GraphQL field |
| --- | --- |
| `@GraphQLAll()` | `posts(limit, offset)` |
| `@GraphQLPaginate()` | `posts(first, page)` |
| `@GraphQLFind()` | `post(id)` |
| `@GraphQLCreate(dto:)` | `createPost(input)` |
| `@GraphQLUpdate(dto:)` | `updatePost(id, input)` |
| `@GraphQLDelete()` | `deletePost(id)` |

Create and update use a DTO, so the input gets the same validation as your HTTP routes.

To write your own query, put `@GraphQLQuery()` on a method:

```dart
class PostResolver {
  @GraphQLQuery()
  Future<List<Post>> latestPosts() => Post().orderBy('id', 'desc').limit(10).get();
}
```

## Protect the API

Set `guard: true` on an operation that a guest must not use. Give an ability with `can:`, and Dox asks the policy of the model before the operation runs:

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

- `filter:` hides the rows that the user can not see.
- `owner: 'userId'` sets the owner of a new row to the logged-in user.
- A denied guest gets `UNAUTHENTICATED`, and a denied user gets `FORBIDDEN`. The other fields of the request still give their data.

Policies need `dox_auth` 3.2.2 or newer.

## Safe in production

In production, GraphiQL and introspection are off, and error details stay on the server. You do not set anything for this.

Limits stop a very large query before it causes much work on your server. For example, a query can nest 64 levels (`maxDepth`) and load 100,000 values (`maxNodes`). Set lower values in `GraphQLConfig` when your API is open to the public.

## Versions

| Package | Version |
| --- | --- |
| `dox_graphql` | 0.0.1 (new) |
| `dox_graphql_builder` | 0.0.1 (new) |
| `dox_graphql_orm` | 0.0.1 (new) |

The GraphQL packages have their own version line, because they are new.

For more, read [GraphQL](/latest/packages/graphql/).
