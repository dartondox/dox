---
icon: lucide/bot
---

# MCP server

`dox_mcp` serves your app's tools to AI clients like Claude, ChatGPT and IDE agents, with the [Model Context Protocol](https://modelcontextprotocol.io) (MCP).

A tool is an action the AI can call, like "add an expense". You write the tool in Dart, and `dox_mcp` serves it from a normal Dox route over the Streamable HTTP transport.

- Tool arguments are `dox_validation` schemas. Clients see them as JSON Schema, and every call is checked before your code runs.
- Session ids are signed with `APP_KEY`, so a session works on every isolate and after a restart. No store is needed.
- Replies are plain JSON. No SSE stream is needed for tools.

## Setup

Run:

```bash
dox add mcp
```

It adds the package, `lib/config/mcp.dart` with an `McpServer`, and a sample tool in `lib/app/mcp/echo.tool.dart`. You add the route and the auth yourself. It never overwrites a file, so it is safe to run twice.

To set it up by hand, add the package:

```bash
dart pub add dox_mcp
```

## Writing tools

A tool extends `McpTool`. It has a `name`, a `description` for the model, an `input` schema, and a `call` method that does the work:

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

If the arguments are wrong, the client gets a tool result with `isError: true` that lists each problem, so the model can fix the call. If your tool throws, the client also gets a tool result with `isError: true` and the error text.

### Small tools

A small tool can be a function. Use `McpTool.of`:

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

### Tools that take a DTO

If you already have a `@Dto` class, a tool can use it as its input. Extend `McpDtoTool<T>`. The rules of the DTO (like `@Length` and `@HexColor`) are written once, and `handle` gets the typed object, not a map.

Use `@Describe` on a field to explain it to the model. It goes into the JSON Schema as `description`, and it does not change the checks:

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

The arguments are checked like a DTO in a controller, also with async rules like `@Unique` and `@Exists`. A bad call gets a text like this:

```text
Input validation error: Invalid arguments for tool create_category: name: The name is required; color: The color must be a hex color like #1a2b3c
```

## Serving the tools

Make an `McpServer` with your tools, and call `handle` from a route. The MCP route has no auth of its own, so you must check who calls first. Find the user (from a token, a header or the URL) and pass it as `auth`. The `scope` ties each session to that user:

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

In a tool, `context.authAs<User>()` gives this user back.

A token in the URL ends up in proxy logs. So prefer a header when your clients can send one. If you want clients to sign in by themselves, use [OAuth](#signing-in-with-oauth).

## Signing in with OAuth

With `McpOAuth`, you give the client only the address, like `https://my.app/mcp`. The client finds the rest and signs the user in. This is the sign-in the MCP spec asks for: OAuth 2.1 with PKCE.

`dox_mcp` does the OAuth part. Your app does three things:

1. **Tokens.** Implement `McpOAuthTokens`. `issue` makes a token for a grant. `verify` gives what a token stands for (like a user), or `null`. You choose the table and how a token is revoked. Keep only a hash of the token.
2. **The consent page.** Serve it at `<issuer>/oauth/authorize`, or set `authorizePage`. It reads `client_id`, `redirect_uri`, `state`, `code_challenge`, `code_challenge_method` and `resource` from the query. The person signs in there the way your app always does.
3. **The answer.** Your page calls a route of your own, behind your own login. On yes, the route calls `oauth.approve(subject: ...)` and gives the page the address to send the browser to. On no, it calls `oauth.deny(...)`.

Then add the routes and check the token on the MCP route:

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

Call `oauth.routes()` in a router with no prefix, because clients look for `/.well-known/...` at the root of the host. The `codes` store must be shared by all isolates: a file store on one host, or Redis on many.

### Keeping the consent page safe

The consent page decides who gets access, so keep these rules:

- Put the answer route behind [CSRF protection](../security/csrf.md). Without it, another site can make a signed-in person say yes to a client without knowing it.
- Use `oauth.checkClient(...)` to get the client for the page. It throws when the client or the redirect address is wrong. Then never send the browser anywhere.
- Show the redirect host, so the person sees where the browser goes.
- HTML-escape the client name before you print it. The client chose the name, so do not trust it.

There is no refresh token. To revoke a client, delete its token.

## Sessions

`SignedMcpSessions` is the default. It makes ids like `<random>.<signature>`, signed with a key made from `APP_KEY`. So every isolate, and every server with the same `APP_KEY`, can check an id, and nothing is stored. A new `APP_KEY` ends every session, and clients start a new one by themselves.

Because nothing is stored, a signed id can not be ended. If you want `DELETE` to end a session, give a cache store that all isolates share (file or Redis, not memory):

```dart
SignedMcpSessions(ended: Cache().store('redis'))
```

For another kind of session, implement `McpSessions`.

## Security

- The MCP route has no auth of its own. Check who calls before `handle`. `McpOAuth` is one way to do it.
- Set `allowedOrigins` when the server runs on a local or private network. It stops browser pages on other sites (DNS rebinding). A request with an `Origin` that is not in the list gets `403`.
- Keep tokens out of logs.

## Details

This section is for special cases. Most apps do not need it.

### What the server answers

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

- Methods: `initialize`, `ping`, `tools/list`, `tools/call`. Others get `-32601 Method not found`.
- An unknown tool is a JSON-RPC error (`-32602`).
- `tools/list` sends the JSON Schema of a DTO tool (`toJsonSchema()`) as `inputSchema`.
- `onToolError` gets the error of a tool that throws, for logs.
- Protocol versions: `2025-11-25`, `2025-06-18`, `2025-03-26` and `2024-11-05`. A client that asks for another one gets the newest.
- The session signature is HMAC-SHA256 of the random part and the `scope`. The key is made from `APP_KEY` with the label `dox:mcp`.

### OAuth routes

`oauth.routes()` adds these routes:

| Route | What it does |
| --- | --- |
| `GET /.well-known/oauth-protected-resource` (also with `/mcp` after it) | Names the MCP address and the issuer. |
| `GET /.well-known/oauth-authorization-server` | Lists the endpoints. PKCE `S256` only, `authorization_code` only, no client secret. |
| `POST /oauth/register` | Dynamic client registration. Nothing is stored. The `client_id` is the name and the redirect addresses, signed with `APP_KEY`. |
| `POST /oauth/token` | Swaps a code for a token. The body is a form or JSON. The code works once, for `codeTtl` (1 minute). The client, the redirect address and the PKCE verifier must all match. An unknown `client_id` gets `401` with `invalid_client`. |

- The discovery file gives `<issuer>/oauth/register` and `<issuer>/oauth/token` as full addresses. Under a router prefix the routes move but these addresses do not, so clients can not find them.
- A redirect address must be `https`, or `http` on `localhost`, `127.0.0.1` or `[::1]`. It has no `#fragment`. It has at most 2048 characters (`McpOAuth.maxRedirectUriLength`).
- A `code_verifier` must be 43 to 128 characters of `A-Z a-z 0-9 - . _ ~` (RFC 7636). Other verifiers get `invalid_request`. A `code_challenge` must be 43 base64url characters.
- Each code is taken under a lock, so two isolates can not both swap it.
- These routes answer any origin (CORS `*`) and read no cookie. They skip the CORS list of the app.
- `issue` may throw `McpOAuthException`, like `access_denied` when a person has too many clients. The client gets it from the token endpoint.
