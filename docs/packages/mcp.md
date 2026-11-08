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

## What the server answers

| Request | Answer |
| --- | --- |
| `POST` `initialize` | `200` with the server info and an `Mcp-Session-Id` header |
| `POST` a request with a valid `Mcp-Session-Id` | `200` with the JSON-RPC response (a list for a batch) |
| `POST` only notifications or responses | `202`, no body |
| `POST` with no session id | `400` |
| `POST` with an unknown or ended session id, or one of another `scope` | `404`, so the client starts a new session |
| `POST` with an unsupported `MCP-Protocol-Version` header | `400` |
| `POST` with another `Content-Type` than JSON | `415` |
| `GET` | `405`: there is no server-to-client stream |
| `DELETE` with a session id | `200`, the session ends |

Methods: `initialize`, `ping`, `tools/list`, `tools/call`. Others get `-32601 Method not found`.

- An unknown tool is a JSON-RPC error (`-32602`).
- Bad arguments are a tool result with `isError: true` and the problems, so the model can fix them.
- A tool that throws gives a tool result with `isError: true` and the error text. `onToolError` gets the error, for logs.

Protocol versions: `2025-11-25`, `2025-06-18`, `2025-03-26` and `2024-11-05`. A client that asks for another one gets the newest.

## Sessions

`SignedMcpSessions` (the default) makes ids like `<random>.<signature>`. The signature is HMAC-SHA256 of the random part and the `scope`, with a key made from `APP_KEY` (label `dox:mcp`).

- Every isolate, and every server with the same `APP_KEY`, can check an id. Nothing is stored.
- A new `APP_KEY` ends every session. Clients start a new one by themselves.
- A signed id can not be ended by itself. To refuse ended ids, give a cache store: `SignedMcpSessions(ended: Cache().store('redis'))`. Use a store that all isolates share (file or Redis, not memory).

For another kind of session, implement `McpSessions`.

## Security

- Check who calls before `handle`: the MCP route has no auth of its own.
- `allowedOrigins` stops browser pages on other sites (DNS rebinding). Set it when the server runs on a local or private network.
- Keep tokens out of logs. A token in the URL ends up in proxy logs, so prefer a header when your clients can send one.
