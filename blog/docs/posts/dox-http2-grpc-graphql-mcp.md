---
date:
  created: 2026-11-21
authors:
  - dox
categories:
  - Releases
tags:
  - release
slug: dox-http2-grpc-graphql-mcp
---

# HTTP/2, gRPC, GraphQL and MCP 2026-07-28 in Dox

This release adds four features: HTTP/2 on the same port as HTTP/1.1, gRPC services, a GraphQL API made from your models, and the MCP protocol `2026-07-28`. The existing packages get patch versions, and gRPC and GraphQL are new packages. HTTP/2 is off by default, so an app that does not turn it on works as before.

<!-- more -->

> **Key takeaways**
>
> - **HTTP/2.** Set `http2: true` in the app config. The same port then serves HTTP/1.1 and HTTP/2. Routes, middleware and controllers do not change.
> - **gRPC.** The new `dox_grpc` package serves `protoc`-generated services next to your HTTP routes, with your Dox middleware before each call.
> - **GraphQL.** The new `dox_graphql` package makes a GraphQL API from your models with annotations. Policies control each field.
> - **MCP 2026-07-28.** `dox_mcp` speaks the new protocol and the older versions on the same route. A tool can now ask the user a question during a call.
> - **Easy to update.** Patch versions only. Run `dart pub upgrade`, then check [Read before you update](#read-before-you-update).

## Versions

| Package | New version |
| --- | --- |
| `dox_core` | 3.2.4 |
| `dox_http_native` | 3.2.2 |
| `dox_cache`, `dox_auth`, `dox_mcp`, `dox_mailer`, `dox_socketio`, `ioredis` | 3.2.2 |
| `dox_orm`, `dox_migration`, `dox_cache_database` | 3.2.3 |
| `dox_openapi`, `dox_validation` | 3.2.1 |
| `dox_inertia`, `dox` CLI | 3.2.3 |
| `dox_grpc` | 0.0.1 (new) |
| `dox_graphql`, `dox_graphql_builder`, `dox_graphql_orm` | 0.0.1 (new) |
| App template | v3.2.4 |

No change: `dox_annotation`, `dox_builder`, `dox_queue`, `dox_queue_database`, `dox_scheduler`, `dox_storage`, `dox_view`, `dox_postgres_native` and `dox_mysql_native`.

## How to update

1. Get the new versions:

    ```bash
    dart pub upgrade
    ```

    Upgrade `dox_core` and `dox_http_native` together. `dox_core` 3.2.4 needs `dox_http_native` 3.2.2.

2. Read [Read before you update](#read-before-you-update). Most apps need nothing more.

## HTTP/2

With HTTP/2, one connection can send many requests at the same time. Use it when your proxy sends HTTP/2 to the app, or when you serve gRPC. Turn it on in the app config:

```dart title="lib/config/app.dart"
AppConfig appConfig = AppConfig(
  http2: true,
  // ...
);
```

The port then accepts HTTP/1.1 and HTTP/2. Dox finds the protocol of each connection, so old clients and health checks continue to work. `req.protocolVersion` gives `2.0` for an HTTP/2 request.

Dox serves HTTP/2 over plain TCP (h2c). Put a proxy in front of the app for TLS, as for HTTP/1.1. The server has limits against HTTP/2 floods, such as Rapid Reset (CVE-2023-44487) and too many PING or SETTINGS frames. The h2spec conformance suite runs in CI.

The new app template has an `APP_HTTP2` key for this. Set `APP_HTTP2=true` in `.env` to turn on HTTP/2.

See [HTTP/2](/latest/digging-deeper/http2/).

## gRPC

`dox_grpc` serves gRPC services on the same port as your HTTP routes. You write the calls one time in a `.proto` file, and each side gets typed code from this file. A client in any language can call the service, because it is standard gRPC.

Set up gRPC in your app:

```bash
dox add grpc
```

The command adds the packages, a sample `protos/greeter.proto`, a router with the health service, and `APP_HTTP2` in `.env`. Then register your service in a router that has no prefix:

```dart title="lib/routes/grpc.dart"
class GrpcRouter extends Router {
  @override
  void register() {
    Grpc.register(GreeterService());
  }
}
```

All four call types work: unary, server streaming, client streaming and bidirectional streaming. Your Dox middleware runs before each call, so gRPC and HTTP can use the same auth. Deadlines, cancel, metadata, gzip, message size limits and the `grpc.health.v1` health service are included.

CI tests `dox_grpc` with the grpc-go interop suite, directly and behind nginx and Caddy, and with `grpcurl`.

See [gRPC](/latest/digging-deeper/grpc/).

## GraphQL

`dox_graphql` makes a GraphQL API from your models. Put `@GraphQL()` on a model, and add one annotation for each operation that a client can use:

```dart title="lib/app/models/post/post.model.dart"
@DoxModel()
@GraphQL()
@GraphQLAll(can: Ability.viewAny)
@GraphQLFind(can: Ability.view)
@GraphQLCreate(dto: PostInput, can: Ability.create, guard: true)
class Post extends PostGenerator {}
```

The columns and relations of the model become fields. An operation with no annotation does not exist. `can:` is an ability of the model policy, so a denied user gets `FORBIDDEN` and a denied guest gets `UNAUTHENTICATED`. A `DataLoader` loads relations in batches, so a list of posts with their users does not make one query for each post.

Set up GraphQL in your app:

```bash
dox add graphql
```

In development, `http://localhost:3000/graphql` opens GraphiQL, a page where you write and run queries. Policies need `dox_auth` 3.2.2 or newer.

See [GraphQL](/latest/packages/graphql/).

## MCP 2026-07-28

`dox_mcp` now speaks the MCP protocol `2026-07-28`, next to the older versions on the same route. Your tools do not change, and old clients work as before. A `2026-07-28` client needs no `initialize` call and no session.

A tool can now ask the user a question during a call. Return `McpToolResult.inputRequired` with the inputs, and read the answer from the context on the next round:

```dart
McpInput<bool> confirmDelete = McpInput.confirm('Delete 12 files?');

McpAnswer<bool>? answer = context.answer(confirmDelete);
if (answer == null) {
  return McpToolResult.inputRequired(<McpInput<Object?>>[confirmDelete]);
}
return switch (answer) {
  McpAccepted<bool>(value: true) => _delete(args),
  McpAccepted<bool>() ||
  McpDeclined<bool>() ||
  McpCancelled<bool>() => McpToolResult.text('Cancelled'),
};
```

The server also accepts OAuth client metadata documents (CIMD), the way the new spec asks clients to register. It loads them with guards against server-side request forgery. Older clients can still use `POST /oauth/register`.

See [MCP](/latest/packages/mcp/).

## Other changes

- **Core.** `req.takeOverResponse()`, `Route.fallback(controller, when:)`, `.withoutMiddleware<T>()` and `.renderErrorsWith(renderer)` on a route. `showErrors()` is public.
- **Auth.** `Ability` constants (`viewAny`, `view`, `create`, `update`, `delete`). A number in a login field now goes into the query as text. Before, on MySQL, `{"email": 0}` matched almost any user. On Postgres, a login value that does not fit a number column is a failed login, not a 500.
- **ORM.** A stored enum value that the enum does not have no longer makes the whole query fail. A nullable field reads it as null and logs a warning. New `EnumCast(..., unknown:)`.
- **OpenAPI.** A `:` in a route path, like `/books:search`, stays in the docs. The docs build is faster for apps with many routes.
- **Socket.IO.** `Broadcast.socketId(req)` ignores an `X-Socket-ID` that is not a socket id. Before, a room name there made `toOthers` skip the whole room.
- **ioredis.** Many fixes in subscriber mode. Every subscriber of a channel or pattern now gets each message.
- **Inertia.** `dox inertia:install --ssr` and `dox inertia:start-ssr` for React server-side rendering.
- **CLI.** `seeders.dart` and `migrations.dart` no longer list `abstract` or `sealed` classes.

## Read before you update

- **Cache.** User keys that start with `lock:`, `tag:`, `flexible:created:` or `#` are stored under a new name, so they miss the cache one time after the update. This fixes keys that could hit internal keys of the cache.
- **Validation.** Some input that passed before now fails, because the old result was wrong. Dates that do not exist (like `2024-02-31`), `Infinity`, hex text like `"0x1F"` in number rules, and a DTO `int` above 2^53 now fail.
- **Mailer.** An email address with a character that is not ASCII, like `user@münchen.de`, now throws a `MailException`. Write the domain in punycode: `user@xn--mnchen-3ya.de`. Names, subjects and file names can still be any text.
- **Socket.IO.** Text packets are limited to 32 levels of JSON depth by default. Set `ServerOptions.maxDepth` if your app sends deeper data.
- **ioredis.** `RedisConnection.patternListeners` is now `Map<String, List<RedisSubscriber>>`.
- **OpenAPI.** The spec no longer has the `x-dox-middleware` extension.

The full lists are in the CHANGELOG of each package on pub.dev.
