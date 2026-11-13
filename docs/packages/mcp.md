---
icon: lucide/bot
---

# MCP server

A [Model Context Protocol](https://modelcontextprotocol.io) (MCP) server for the [Dox](https://dartondox.dev) framework.

It serves tools to MCP clients (Claude, ChatGPT, IDE agents) over the Streamable HTTP transport, from a normal Dox route.

- Tool arguments are `dox_validation` schemas: clients see them as JSON Schema, and every call is checked before your code runs.
- Session ids are signed with `APP_KEY`, so a session made on one isolate works on every isolate, and after a restart. No store is needed.
- Replies are plain JSON. No SSE stream is needed for tools.

## Install

```bash
dox add mcp
```

It adds the package, `lib/config/mcp.dart` with an `McpServer`, and a sample tool in `lib/app/mcp/echo.tool.dart`. You add the route and the auth.
It never overwrites a file, so it is safe to run twice.

### Set it up by hand

```bash
dart pub add dox_mcp
```

## Use

Write a tool:

```dart
import 'package:dox_core/dox_core.dart';
import 'package:dox_mcp/dox_mcp.dart';

class AddExpense extends McpTool {
  @override
  String get name => 'add_expense';

  @override
  String get description => 'Record an expense. Amount is in dollars.';

  @override
  ObjectSchema get input => v.object(<String, Schema<Object?>>{
    'amount': v.num().positive().describe('Amount, like 12.50.'),
    'note': v.string().max(500).optional(),
  });

  @override
  Future<McpToolResult> call(Map<String, dynamic> args, McpContext context) async {
    User user = context.authAs<User>();
    // ... save it
    return McpToolResult.text('Recorded ${args['amount']} for ${user.email}.');
  }
}
```

Serve it on a route. Find the user first (from a token, a header or the URL), and pass it as `auth`. `scope` ties each session to that user:

```dart
final McpServer mcp = McpServer(
  name: 'my-app',
  version: '1.0.0',
  tools: <McpTool>[AddExpense()],
);

Route.match(<String>['GET', 'POST', 'DELETE'], '/mcp/{token}', (DoxRequest req) async {
  User? user = await User().where('mcp_token', req.param['token']).getFirst();
  if (user == null) return response('Invalid token').statusCode(401);
  return mcp.handle(req, auth: user, scope: 'user:${user.id}');
});
```

A small tool can be a function:

```dart
McpTool.of(
  name: 'echo',
  description: 'Say the text back.',
  input: v.object(<String, Schema<Object?>>{'text': v.string()}),
  handler: (Map<String, dynamic> args, McpContext context) {
    return McpToolResult.text(args['text'] as String);
  },
);
```

## Tools that take a DTO

A tool can take a `@Dto` class as its input. Extend `McpDtoTool<T>`. The rules of the DTO (like `@Length` and `@HexColor`) are written once, and `handle` gets the typed object, not a map.

Use `@Describe` on a field to explain it to the model. It goes into the JSON Schema as `description`. It does not change the checks.

```dart
@Dto()
class NewCategory {
  @Describe('The category name, like Food.')
  @Length(min: 1, max: 50)
  final String name;

  @Describe('A color, like #1a2b3c.')
  @HexColor()
  final String color;

  const NewCategory({required this.name, required this.color});

  static const DtoSchema<NewCategory> schema = $NewCategoryDto;
}

class CreateCategory extends McpDtoTool<NewCategory> {
  @override
  String get name => 'create_category';

  @override
  String get description => 'Add a category.';

  @override
  DtoSchema<NewCategory> get dto => NewCategory.schema;

  @override
  Future<McpToolResult> handle(NewCategory input, McpContext context) async {
    // ... save it
    return McpToolResult.text('Added ${input.name}.');
  }
}
```

- `tools/list` sends the JSON Schema of the DTO (`toJsonSchema()`) as `inputSchema`.
- The arguments are checked like a DTO in a controller, with async rules like `@Unique` and `@Exists` too.
- Bad arguments are a tool result with `isError: true`, not a JSON-RPC error. The text lists each problem, so the model can fix the call:

```text
Input validation error: Invalid arguments for tool create_category: name: The name is required; color: The color must be a hex color like #1a2b3c
```

## What the server answers

| Request | Answer |
| --- | --- |
| `POST` `initialize` | `200` with the server info and an `Mcp-Session-Id` header |
| `POST` a request with a valid `Mcp-Session-Id` | `200` with the JSON-RPC response (a list for a batch) |
| `POST` only notifications or responses | `202`, no body |
| `POST` with no session id | `400` |
| `POST` with an unknown session id, or one of another `scope` | `404`, so the client starts a new session |
| `POST` with an ended session id | `404`, only when `SignedMcpSessions` has an `ended` store. Without it, the id still works |
| `POST` with a body that is not valid JSON | `400` with the JSON-RPC error `-32700` |
| `POST` with an empty batch, or a message that is not JSON-RPC 2.0 | `400` with the JSON-RPC error `-32600` |
| `POST` with `initialize` in a batch with other messages | `400` with the JSON-RPC error `-32600`. Send `initialize` alone |
| `POST` with an unsupported `MCP-Protocol-Version` header | `400` |
| `POST` with another `Content-Type` than JSON | `415` |
| Any request with an `Origin` header that is not in `allowedOrigins` | `403` |
| `GET` | `405`: there is no server-to-client stream |
| `DELETE` with a valid session id | `200`. The session ends only if `SignedMcpSessions` has an `ended` store (see [Sessions](#sessions)) |
| `DELETE` with no session id | `400` |
| `DELETE` with an unknown session id, or one of another `scope` | `404`. An ended id also gets `404` when there is an `ended` store |

Methods: `initialize`, `ping`, `tools/list`, `tools/call`. Others get `-32601 Method not found`.

- An unknown tool is a JSON-RPC error (`-32602`).
- Bad arguments are a tool result with `isError: true` and the problems, so the model can fix them.
- A tool that throws gives a tool result with `isError: true` and the error text. `onToolError` gets the error, for logs.

Protocol versions: `2025-11-25`, `2025-06-18`, `2025-03-26` and `2024-11-05`. A client that asks for another one gets the newest.

## Sessions

`SignedMcpSessions` (the default) makes ids like `<random>.<signature>`. The signature is HMAC-SHA256 of the random part and the `scope`, with a key made from `APP_KEY` (label `dox:mcp`).

- Every isolate, and every server with the same `APP_KEY`, can check an id. Nothing is stored.
- A new `APP_KEY` ends every session. Clients start a new one by themselves.
- A signed id cannot be ended by itself. To refuse ended ids, give a cache store: `SignedMcpSessions(ended: Cache().store('redis'))`. Use a store that all isolates share (file or Redis, not memory).

For another kind of session, implement `McpSessions`.

## OAuth sign-in

`McpOAuth` lets a client sign in by itself. You give the client only the address, like `https://my.app/mcp`. The client finds the rest. This is the sign-in the MCP spec asks for: OAuth 2.1 with PKCE.

`dox_mcp` does the OAuth part. Your app does three things:

1. **Tokens.** Implement `McpOAuthTokens`. `issue` makes a token for a grant. `verify` gives what a token stands for (like a user), or `null`. You choose the table and how a token is revoked. Keep only a hash of the token.
2. **The consent page.** Serve it at `<issuer>/oauth/authorize`, or set `authorizePage`. It reads `client_id`, `redirect_uri`, `state`, `code_challenge`, `code_challenge_method` and `resource` from the query. The person signs in there the way your app always does.
3. **The answer.** Your page calls a route of your own, behind your own login. On yes, the route calls `oauth.approve(subject: ...)` and gives the page the address to send the browser to. On no, it calls `oauth.deny(...)`. `oauth.checkClient(...)` gives the client for the page and throws when the client or the redirect address is wrong. Then never send the browser anywhere. Put this route behind [CSRF protection](../security/csrf.md). Without it, another site can make a signed-in person say yes to a client without knowing it.

```dart
final McpOAuth oauth = McpOAuth(
  issuer: 'https://my.app',
  tokens: MyTokens(),
  codes: Cache().store('file'), // all isolates must share it
);

class McpRouter extends Router {
  @override
  void register() {
    oauth.routes(); // discovery, register and token
    Route.match(<String>['GET', 'POST', 'DELETE'], '/mcp', handleMcp);
  }
}

Future<DoxResponse> handleMcp(DoxRequest req) async {
  Object? user = await oauth.authenticate(req); // reads Authorization: Bearer
  if (user == null) return oauth.unauthorized(); // 401 with WWW-Authenticate
  return mcp.handle(req, auth: user, scope: '$user');
}
```

On the consent page, show the redirect host, so the person sees where the browser goes. HTML-escape the client name before you print it. The client chose the name, so do not trust it.

Call `oauth.routes()` in a router with no prefix. The routes must sit at the root of the host. Clients look for `/.well-known/...` at the root, as the OAuth specs say. The discovery file also gives `<issuer>/oauth/register` and `<issuer>/oauth/token` as full addresses. Under a prefix, the routes move, but these addresses do not, so clients cannot find them.

`oauth.routes()` adds these routes:

| Route | What it does |
| --- | --- |
| `GET /.well-known/oauth-protected-resource` (also with `/mcp` after it) | Names the MCP address and the issuer. |
| `GET /.well-known/oauth-authorization-server` | Lists the endpoints. PKCE `S256` only, `authorization_code` only, no client secret. |
| `POST /oauth/register` | Dynamic client registration. Nothing is stored. The `client_id` is the name and the redirect addresses, signed with `APP_KEY`. |
| `POST /oauth/token` | Swaps a code for a token. The body is a form or JSON. The code works once, for `codeTtl` (1 minute). The client, the redirect address and the PKCE verifier must all match. An unknown `client_id` gets `401` with `invalid_client`. |

Rules:

- A redirect address must be `https`, or `http` on `localhost`, `127.0.0.1` or `[::1]`. It has no `#fragment`. It has at most 2048 characters (`McpOAuth.maxRedirectUriLength`).
- A `code_verifier` must be 43 to 128 characters of `A-Z a-z 0-9 - . _ ~` (RFC 7636). Other verifiers get `invalid_request`. A `code_challenge` must be 43 base64url characters.
- The codes live in `codes`, a Dox cache. Use a store that all isolates share (file on one host, Redis on many). Each code is taken under a lock, so two isolates cannot both swap it.
- These routes answer any origin (CORS `*`) and read no cookie. They skip the CORS list of the app.
- `issue` may throw `McpOAuthException`, like `access_denied` when a person has too many clients. The client gets it from the token endpoint.
- There is no refresh token. To revoke a client, delete its token.

## Security

- Check who calls before `handle`: the MCP route has no auth of its own. `McpOAuth` is one way to do it.
- `allowedOrigins` stops browser pages on other sites (DNS rebinding). Set it when the server runs on a local or private network.
- Keep tokens out of logs. A token in the URL ends up in proxy logs, so prefer a header when your clients can send one.
