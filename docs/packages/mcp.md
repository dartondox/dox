---
icon: lucide/bot
---

# MCP server

`dox_mcp` serves the tools of your app to AI clients, for example Claude, ChatGPT, and IDE agents, with the [Model Context Protocol](https://modelcontextprotocol.io) (MCP).

A tool is an action that the AI can call, for example "add an expense". You write the tool in Dart. `dox_mcp` serves it from a normal Dox route over the Streamable HTTP transport.

- Tool arguments are `dox_validation` schemas. Clients see them as JSON Schema. Dox validates each call before your code runs.
- `APP_KEY` signs the session ids. Thus, a session works on all isolates and after a restart. You do not need a store.
- Replies are plain JSON. Tools do not need an SSE stream.

## Setup

Run:

```bash
dox add mcp
```

The command adds the package, `lib/config/mcp.dart` with an `McpServer`, and a sample tool in `lib/app/mcp/echo.tool.dart`. You add the route and the auth yourself. The command does not overwrite a file. It is safe to run it again.

To set up the package manually, add it:

```bash
dart pub add dox_mcp
```

## Write tools

A tool extends `McpTool`. A tool has these parts:

- `name`: the name of the tool.
- `description`: the text for the model.
- `input`: the schema of the arguments.
- `call`: the method that does the work.

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

If the arguments are not correct, the client gets a tool result with `isError: true`. This result lists each problem, so that the model can correct the call. If your tool throws an error, the client also gets a tool result with `isError: true` and the error text.

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

If you have a `@Dto` class, a tool can use it as its input. Extend `McpDtoTool<T>`. You write the rules of the DTO one time, for example `@Length` and `@HexColor`. The `handle` method gets the typed object, not a map.

Use `@Describe` on a field to explain the field to the model. Dox puts this text in the JSON Schema as `description`. It does not change the validation:

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

Dox validates the arguments the same as a DTO in a controller. This includes async rules, for example `@Unique` and `@Exists`. A call that is not correct gets a text like this:

```text
Input validation error: Invalid arguments for tool create_category: name: The name is required; color: The color must be a hex color like #1a2b3c
```

## Serve the tools

Make an `McpServer` with your tools, and call `handle` from a route. The MCP route has no auth. Thus, you must find the caller first. Get the user from a token, a header, or the URL, and give it as `auth`. The `scope` connects each session to that user:

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

In a tool, `context.authAs<User>()` gives this user.

Proxies write a token in the URL to their logs. Thus, use a header when your clients can send one. If you want clients to sign in without your help, use [OAuth](#sign-in-with-oauth).

## Sign in with OAuth

With `McpOAuth`, you give the client only the address, for example `https://my.app/mcp`. The client finds the other data and signs in the user. The MCP spec asks for this sign-in: OAuth 2.1 with PKCE.

`dox_mcp` does the OAuth part. Your app does three things:

1. **Tokens.** Implement `McpOAuthTokens`. `issue` makes a token for a grant. `verify` gives the subject of a token, for example a user, or `null`. You choose the table and how to revoke a token. Keep only a hash of the token.
2. **The consent page.** Serve the page at `<issuer>/oauth/authorize`, or set `authorizePage`. The page reads `client_id`, `redirect_uri`, `state`, `code_challenge`, `code_challenge_method`, and `resource` from the query. The person signs in on this page with the usual login of your app.
3. **The answer.** Your page calls a route of your app, behind your login. If the person agrees, the route calls `oauth.approve(subject: ...)`. Then the route gives the page the address for the browser. If the person refuses, the route calls `await oauth.denyClient(...)`.

Then add the routes, and verify the token on the MCP route:

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

Call `oauth.routes()` in a router with no prefix, because clients look for `/.well-known/...` at the root of the host. All isolates must share the `codes` store. Use a file store on one host, or Redis on many hosts.

### Keep the consent page safe

The consent page controls who gets access. Obey these rules:

- Put the answer route behind [CSRF protection](../security/csrf.md). If you do not, a different site can make a signed-in person agree to a client. The person does not know about it.
- Use `await oauth.verifyClient(...)` to get the client for the page. This method throws an error when the client or the redirect address is not correct. In that case, do not send the browser to any address.
- Show `client.host` next to the client name, and show the redirect host. A client can choose any name, but not its host. Then the person sees who asks and where the browser goes.
- HTML-escape the client name before you show it. The client chose the name, so do not trust it.

There is no refresh token. To revoke a client, delete its token.

## Sessions

`SignedMcpSessions` is the default. It makes ids like `<random>.<signature>`. A key from `APP_KEY` signs each id. Thus, each isolate and each server with the same `APP_KEY` can verify an id, and Dox stores nothing. A new `APP_KEY` stops all sessions. Then clients start a new session automatically.

Dox stores nothing, so you cannot stop a signed id. If you want `DELETE` to stop a session, give a cache store that all isolates share. Use a file store or Redis, not memory:

```dart
SignedMcpSessions(ended: Cache().store('redis'))
```

For a different type of session, implement `McpSessions`.

## Security

- The MCP route has no auth. Find the caller before `handle`. `McpOAuth` is one way to do this.
- Set `allowedOrigins` when the server runs on a local or private network. This setting stops browser pages from other sites. This attack is DNS rebinding. If the `Origin` of a request is not in the list, the request gets `403`.
- Keep tokens out of logs.

## Details

This section gives special cases. Most apps do not need it.

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
| `POST` with a batch of more than 50 messages | `400` with the JSON-RPC error `-32600`. No message runs |
| `POST` with an unsupported `MCP-Protocol-Version` header | `400` |
| `POST` with another `Content-Type` than JSON | `415` |
| Any request with an `Origin` header that is not in `allowedOrigins` | `403` |
| `GET` | `405`: there is no server-to-client stream |
| `DELETE` with a valid session id | `200`. The session ends only if `SignedMcpSessions` has an `ended` store (see [Sessions](#sessions)) |
| `DELETE` with no session id | `400` |
| `DELETE` with an unknown session id, or one of another `scope` | `404`. An ended id also gets `404` when there is an `ended` store |

- Methods: `initialize`, `ping`, `tools/list`, `tools/call`. Other methods get `-32601 Method not found`.
- An unknown tool gets a JSON-RPC error, `-32602`.
- `tools/list` sends the JSON Schema of a DTO tool as `inputSchema`. This schema comes from `toJsonSchema()`.
- `onToolError` gets the error of a tool that throws, for logs.
- Protocol versions: `2025-11-25`, `2025-06-18`, `2025-03-26`, and `2024-11-05`. If a client asks for a different version, it gets the newest version.
- The session signature is HMAC-SHA256 of the random part and the `scope`. Dox makes the key from `APP_KEY` with the label `dox:mcp`.

### OAuth routes

`oauth.routes()` adds these routes:

| Route | What it does |
| --- | --- |
| `GET /.well-known/oauth-protected-resource` (also with `/mcp` after it) | Names the MCP address and the issuer. |
| `GET /.well-known/oauth-authorization-server` | Lists the endpoints. PKCE `S256` only, `authorization_code` only, no client secret. |
| `POST /oauth/register` | Dynamic client registration. Nothing is stored. The `client_id` is the name and the redirect addresses, signed with `APP_KEY`. |
| `POST /oauth/token` | Swaps a code for a token. The body is a form or JSON. The code works once, for `codeTtl` (1 minute). The client, the redirect address and the PKCE verifier must all match. An unknown `client_id` gets `401` with `invalid_client`. |

- The discovery file gives `<issuer>/oauth/register` and `<issuer>/oauth/token` as full addresses. A router prefix moves the routes, but not these addresses. Then clients cannot find the routes.
- A redirect address must use `https`, or `http` on `localhost`, `127.0.0.1`, or `[::1]`. It must not have a `#fragment`. Its maximum length is 2048 characters (`McpOAuth.maxRedirectUriLength`).
- A `code_verifier` must have 43 to 128 characters from `A-Z a-z 0-9 - . _ ~`, as RFC 7636 says. Other verifiers get `invalid_request`. A `code_challenge` must have 43 base64url characters.
- Dox takes each code under a lock. Thus, two isolates cannot both swap the same code.
- These routes accept all origins, with CORS `*`, and read no cookie. They do not use the CORS list of the app.
- `issue` can throw `McpOAuthException`, for example `access_denied` when a person has too many clients. The client gets this error from the token endpoint.

## See also

- [Authentication](../security/authentication.md): users, tokens and login in a Dox app.
- [AI agents](../getting-started/ai-agents.md): help an AI agent write Dox code.
