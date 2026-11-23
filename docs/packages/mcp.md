---
icon: lucide/bot
---

# MCP server

`dox_mcp` lets AI clients like Claude, ChatGPT and IDE agents call tools in your app, with the [Model Context Protocol](https://modelcontextprotocol.io) (MCP).

A **tool** is an action the AI can call, like "add an expense". You write the tool in Dart and serve it from a normal Dox route. The server follows the MCP standard `2026-07-28`: each request stands alone and gets a plain JSON reply, so every isolate and every server can answer any request. Older clients work on the same route. The server has tools only, no MCP resources, prompts or streams.

## Setup

Run:

```bash
dox add mcp
```

It adds the package and writes `lib/config/mcp.dart` with an `McpServer`, and a sample tool in `lib/app/mcp/echo.tool.dart`. It never overwrites a file. To set it up by hand, run `dart pub add dox_mcp` and write those two files yourself.

`APP_KEY` must be set in `.env`, because the server signs data with it.

### Server options

| Option | Default | What it does |
| --- | --- | --- |
| `name` | required | the name of the server, for the client |
| `version` | required | the version of your server, for the client |
| `tools` | required | the tools. Two tools with the same name throw an `ArgumentError` |
| `title` | none | a name for people |
| `instructions` | none | text for the model about how to use the server |
| `allowedOrigins` | none | see [Checking the origin](#checking-the-origin) |
| `onToolError` | none | see [Errors in your code](#errors-in-your-code) |
| `sessions` | `SignedMcpSessions()` | sessions of older clients, see [Sessions](#sessions) |
| `requestStateTtl` | 5 minutes | how long the answers of a question work |
| `requestStateKey` | from `APP_KEY` | the key that signs the answers |

## Making a tool

A tool extends `McpTool`. It has a `name`, a `description` for the model, an `input` schema and a `call` method that does the work:

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
  Future<McpToolResult> call(
    Map<String, dynamic> args,
    McpContext context,
  ) async {
    // ... save it
    return McpToolResult.text('Recorded ${args['amount']}.');
  }
}
```

The `input` is a [validation](validation.md) schema. The client sees it as JSON Schema, and Dox checks every call before `call` runs. A tool can also have a `title` for people, and `annotations` like `{'readOnlyHint': true}`.

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

Extend `McpDtoTool<T>` to use a [`@Dto`](../the-basic/dto.md) class as the input. `handle` gets the typed object, and `@Describe` explains a field to the model:

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
  Future<McpToolResult> handle(
      NewCategory input, McpContext context) async {
    // ... save it
    return McpToolResult.text('Added ${input.name}.');
  }
}
```

Dox checks the arguments like a DTO in a controller, also with async rules like `@Unique` and `@Exists`.

## Tool results

A tool returns an `McpToolResult`.

### Text

`McpToolResult.text` sends one text:

```dart
return McpToolResult.text('Recorded 12.50.');
```

### JSON

`McpToolResult.json` sends a value as JSON text. A map is also sent as structured content:

```dart
return McpToolResult.json(<String, dynamic>{'id': 7, 'amount': 12.5});
```

### Images

For other content, give a list of `McpContent` items:

```dart
return McpToolResult(<McpContent>[
  McpContent.text('The chart of this month:'),
  McpContent.image(base64Png, 'image/png'),
]);
```

## Errors

### Errors the model can fix

Return `McpToolResult.error` when the model can try again, like after a bad id. The model sees the text:

```dart
return McpToolResult.error('No expense has id 7.');
```

Bad arguments work the same way, with no code. The model gets one line with each problem:

```text
Input validation error: Invalid arguments for tool create_category: name: The name is required; color: The color must be a hex color like #1a2b3c
```

### Errors in your code

If a tool throws, the client gets only `Tool failed`, because the real error can hold SQL or host names. The real error is shown only when `APP_ENV` is `development` or `local`. Set `onToolError` to log it:

```dart
McpServer(
  name: 'my-app',
  version: '1.0.0',
  tools: <McpTool>[AddExpense()],
  onToolError: (String tool, Object error, StackTrace stack) {
    Logger.danger('MCP tool $tool failed: $error');
  },
);
```

## Adding the route

Make one `McpServer` with your tools, and call `handle` from a route:

```dart
final McpServer mcp = McpServer(
  name: 'my-app',
  version: '1.0.0',
  tools: <McpTool>[AddExpense(), CreateCategory()],
  allowedOrigins: <String>['https://my.app'],
);

Route.match(<String>['GET', 'POST', 'DELETE'], '/mcp', (DoxRequest req) {
  return mcp.handle(req);
});
```

This route is open to everyone. That is fine only for a public server with no users.

### Checking who calls

The MCP route has no auth. Find the user before `handle`, then give `auth` (the user) and `scope` (a text that names the user):

```dart
Route.match(<String>['GET', 'POST', 'DELETE'], '/mcp',
    (DoxRequest req) async {
  User? user = await findUser(req.header('authorization'));
  if (user == null) return response('Invalid token').statusCode(401);
  return mcp.handle(req, auth: user, scope: 'user:${user.id}');
});
```

In a tool, read the user back:

```dart
User user = context.authAs<User>();
```

!!! warning
    An app with users must always give `scope`. The server binds the data it signs to the scope. Without it, one user can send data that was signed for another user.

Proxies write a token in the URL to their logs, so send tokens in a header. To let clients sign in by themselves, use [OAuth](#signing-in-with-oauth).

## Reading the client

### What the client can do

`context.clientCapabilities` tells what the client supports:

```dart
McpClientCapabilities? client = context.clientCapabilities;
if (client != null && client.elicitationForm) {
  // the client can show a form to the user
}
```

It has `elicitation`, `elicitationForm`, `elicitationUrl`, `sampling`, `roots` and `extensions`. For other paths, `has` checks one, like `client.has(<String>['sampling', 'tools'])`. It is null for older clients.

### Which client it is

`context.clientInfo` gives the name and version of the client, or null:

```dart
String name = context.clientInfo?.name ?? 'unknown';
```

!!! warning
    The client says this about itself. Never use it for security.

## Asking the user

A tool can stop and ask the user a question, like "Delete this expense?". The client shows it, then calls the tool again with the answer. Make the question one time, in a `static final` field. The same object asks the question and reads the answer:

```dart
class DeleteExpense extends McpTool {
  static final McpInput<bool> confirmDelete = McpInput.confirm(
    'Delete this expense?',
  );

  // name, description, input ...

  @override
  Future<McpToolResult> call(
    Map<String, dynamic> args,
    McpContext context,
  ) async {
    McpAnswer<bool>? answer = context.answer(confirmDelete);
    if (answer == null) {
      return McpToolResult.inputRequired(
          <McpInput<Object?>>[confirmDelete]);
    }
    return switch (answer) {
      McpAccepted<bool>(value: true) => _delete(args),
      McpAccepted<bool>() ||
      McpDeclined<bool>() ||
      McpCancelled<bool>() => McpToolResult.text('Cancelled'),
    };
  }
}
```

The tool runs two times: first it asks, then `context.answer` gives the answer. It works the same in `McpDtoTool.handle`. The answers are signed, work only for the same user, tool and arguments, and expire after `requestStateTtl`.

!!! warning
    The answers can be sent again until they expire. A tool that must run only one time, like a payment, must check that itself.

A question the client can not show gets an error that names the missing capability. An older client can not answer a question.

### Reading the answer

`context.answer` gives null when there is no answer yet, or the answer can not be read (like a form that fails the DTO rules). Then return `McpToolResult.inputRequired`. Else the answer is one of three classes:

- `McpAccepted<T>`: the user answered. `value` holds the answer.
- `McpDeclined<T>`: the user said no.
- `McpCancelled<T>`: the user closed the question.

### Yes or no

`McpInput.confirm` asks a yes or no question. The answer is a bool:

```dart
static final McpInput<bool> confirmDelete = McpInput.confirm(
  'Delete this expense?',
);
```

### Text

`McpInput.text` asks for one line of text. The answer is a string:

```dart
static final McpInput<String> askNote = McpInput.text('Add a note:');
```

### Number

`McpInput.number` asks for a number. The answer is a `num`:

```dart
static final McpInput<num> askAmount = McpInput.number('How much was it?');
```

### Choice

`McpInput.choice` lets the user pick one value of an enum:

```dart
enum Color { red, green, blue }

static final McpInput<Color> askColor = McpInput.choice(
  'Pick a color:',
  Color.values,
);
```

### Form

`McpInput.form` asks for many fields at once, from a `@Dto` class. The answer is the DTO object, checked by its rules:

```dart
static final McpInput<NewExpense> askExpense = McpInput.form(
  'New expense',
  NewExpense.schema,
);
```

A form has flat fields only: text, numbers, booleans, enums and lists of enum values. The DTO can not have a nested object or async rules like `@Unique`.

!!! warning
    Never ask for a password or a key in a form. Use a URL for that.

### URL

`McpInput.url` sends the user to a page, like a sign-in to another service. Use it for data that must not go through the client:

```dart
static final McpInput<void> connectBank = McpInput.url(
  'Connect your bank account.',
  'https://my.app/bank/connect',
);
```

`McpAccepted` means only that the user agreed to open the page, so check the result in your database. Never put a secret in the URL.

### Many questions

To ask many things at once, give a longer list. Read each answer with its own input. Two inputs with the same message throw an `ArgumentError`:

```dart
McpAnswer<String>? note = context.answer(askNote);
McpAnswer<num>? amount = context.answer(askAmount);
if (note == null || amount == null) {
  return McpToolResult.inputRequired(
      <McpInput<Object?>>[askNote, askAmount]);
}
```

A tool can also ask one question per round. Answers of earlier rounds are kept.

### Custom inputs

For a kind of input that `dox_mcp` does not have, extend `McpCustomInput<T>`. Give the `method`, the `capability` the client needs, the request as `toJson`, and `parse` to read the result:

```dart
class ListRoots extends McpCustomInput<List<String>> {
  @override
  String get method => 'roots/list';

  @override
  List<String> get capability => <String>['roots'];

  @override
  Map<String, Object?> toJson() {
    return <String, Object?>{};
  }

  @override
  List<String> parse(Map<String, Object?> result) {
    return <String>[
      for (Object? root in result['roots']! as List<Object?>)
        (root! as Map<String, Object?>)['uri']! as String,
    ];
  }
}
```

Use it like any other input, with `context.answer` and `McpToolResult.inputRequired`.

## Signing in with OAuth

With `McpOAuth`, you give the client only the address, like `https://my.app/mcp`. The client finds the rest and signs the user in, with OAuth 2.1 and PKCE. Your app makes the tokens and shows the consent page.

| Option | Default | What it does |
| --- | --- | --- |
| `issuer` | required | the address of your app, like `https://my.app` |
| `tokens` | required | your `McpOAuthTokens` |
| `codes` | the default cache store | the cache store for the one-time codes |
| `mcpPath` | `/mcp` | the path of the MCP route |
| `authorizePage` | `<issuer>/oauth/authorize` | the address of the consent page |
| `codeTtl` | 1 minute | how long a code works |
| `resourceName` | none | a name for the server in the discovery file |
| `allowedClientHosts` | none | see [How clients sign in](#how-clients-sign-in) |
| `maxClientFetches` | 8 | see [How clients sign in](#how-clients-sign-in) |
| `maxClientFetchesPerHost` | 2 | see [How clients sign in](#how-clients-sign-in) |
| `clientCacheMaxAge` | 5 minutes | the longest time a client document is kept in memory |
| `clientFetcher` | `McpOAuthHttpFetcher()` | loads client documents. Tests give fake documents |

### Tokens

Implement `McpOAuthTokens`. `issue` makes a token after the user said yes, and can throw an `McpOAuthException`, like `access_denied`. `verify` gives what a token stands for, like the user, or null. Keep only a hash of the token:

```dart
class McpTokens extends McpOAuthTokens {
  @override
  Future<String> issue(McpOAuthGrant grant) async {
    String token = newRandomToken(); // your own long random text
    // ... save Hash.sha256(token) for the user grant.subject
    return token;
  }

  @override
  Future<Object?> verify(String token) async {
    // ... find the user of this token, or return null
    return null;
  }
}
```

!!! warning
    Keep MCP tokens apart from your other tokens, like in their own table. `verify` must accept only a token that `issue` made, so an API token does not work on the MCP route.

There is no refresh token. To revoke a client, delete its token.

### Routes

Make an `McpOAuth` and call `routes` in a router with no prefix, because clients look for `/.well-known/...` at the root of the host. Then check the token on the MCP route:

```dart
final McpOAuth oauth = McpOAuth(
  issuer: 'https://my.app',
  tokens: McpTokens(),
  codes: Cache().store('redis'),
);

class McpRouter extends Router {
  @override
  void register() {
    oauth.routes();
    Route.match(<String>['GET', 'POST', 'DELETE'], '/mcp', handleMcp);
  }
}

Future<DoxResponse> handleMcp(DoxRequest req) async {
  User? user = await oauth.authenticate(req) as User?;
  if (user == null) return oauth.unauthorized();
  return mcp.handle(req, auth: user, scope: 'user:${user.id}');
}
```

`authenticate` reads the `Authorization: Bearer` header and calls your `verify`. `unauthorized` answers 401 and tells the client where to sign in. All isolates must share the `codes` [cache store](../digging-deeper/cache.md), so use `file` on one server, or `redis` on many. The OAuth routes answer any origin and read no cookie.

Add a [rate limit](../security/rate-limiting.md) to the OAuth routes and the MCP route, because anyone can call `/oauth/token`, and each new `client_id` address makes the server load a file:

```dart
Route.middleware(<dynamic>[RateLimit(max: 30)], oauth.routes);
```

### The consent page

The client sends the browser to `<issuer>/oauth/authorize`. This page is yours: the person signs in there the usual way, then says yes or no. The page gets `client_id`, `redirect_uri`, `state`, `code_challenge`, `code_challenge_method` and `resource` in the query.

`verifyClient` gives the client for the page. It throws when the client or the redirect address is wrong:

```dart
McpOAuthClient client = await oauth.verifyClient(clientId, redirectUri);
// show client.name next to client.host, and the host of redirectUri
```

`client.host` is the host of the client address, like `claude.ai`. It is null for an older client that registered. `findClient` gives the client with no redirect check. The older `checkClient` and `deny` are not async: when the client document is not loaded yet, they start the load and throw `invalid_client`. Use `verifyClient` and `denyClient` in new code.

On yes, call `approve`. It gives the address to send the browser to:

```dart
String url = await oauth.approve(
  subject: '${user.id}',
  clientId: clientId,
  redirectUri: redirectUri,
  codeChallenge: codeChallenge,
  codeChallengeMethod: codeChallengeMethod,
  state: state,
  resource: resource,
);
return redirect(url);
```

On no, call `denyClient`:

```dart
String url = await oauth.denyClient(
  clientId: clientId,
  redirectUri: redirectUri,
  state: state,
);
```

The consent page decides who gets access, so keep these rules:

- Put the yes route behind your login and [CSRF protection](../security/csrf.md). Without it, another site can make a signed-in person say yes.
- Show the host of the redirect address, and the host of the `client_id` when it is an `https` address. The client chooses its own name, so the host is the part a person can trust.
- HTML-escape the client name before you print it.

A redirect address must be `https`, or `http` on `localhost`, `127.0.0.1` or `[::1]`.

### How clients sign in

A client names itself with a **client metadata document**. Its `client_id` is an `https` address of a JSON file with the name of the client and its redirect addresses. `dox_mcp` loads the file and checks it, so it stores nothing. Older clients can also register at `POST /oauth/register`.

The server loads only small files from public hosts, and follows no redirects. It keeps a document for its `Cache-Control: max-age`, at most `clientCacheMaxAge`. If the host does not answer, it uses the last document for up to 1 hour. A failed load is not tried again for 1 minute. These options limit the loads:

```dart
McpOAuth(
  issuer: 'https://my.app',
  tokens: McpTokens(),
  allowedClientHosts: <String>{'claude.ai'},
  maxClientFetches: 4,
);
```

- `allowedClientHosts`: load client documents from these hosts only. By default, any public host works. It does not block clients that register.
- `maxClientFetches`: how many documents one isolate loads at the same time. When all are busy, a new client is refused at once.
- `maxClientFetchesPerHost`: how many of these loads can go to one host.
- `McpOAuthHttpFetcher(maxFetchesPerAddress:)`: how many loads can go to one IP address. The default is 2.

## Checking the origin

A web page on another site can try to call your MCP server from the browser of a user. Set `allowedOrigins` to your own sites to stop it, also for a server on `localhost` or a private network:

```dart
McpServer(
  name: 'my-app',
  version: '1.0.0',
  tools: <McpTool>[AddExpense()],
  allowedOrigins: <String>['https://my.app'],
);
```

A request with another `Origin` header gets 403. A request with no `Origin` is not from a browser, so it can always connect. When `allowedOrigins` is not set, the server writes a warning one time at start.

## Sessions

Older clients (MCP `2025-11-25` and before) start with `initialize` and use a session. That is why the route takes GET, POST and DELETE. `SignedMcpSessions` signs each session id with a key from `APP_KEY`, so it stores nothing. A new `APP_KEY` stops all sessions, and clients start new ones.

To make DELETE end a session, give a cache store that all isolates share:

```dart
McpServer(
  name: 'my-app',
  version: '1.0.0',
  tools: <McpTool>[AddExpense()],
  sessions: SignedMcpSessions(ended: Cache().store('redis')),
);
```

For another kind of session, implement `McpSessions`. A batch from an older client can have at most 50 messages.

## Next steps

- [Authentication](../security/authentication.md): users, tokens and login in a Dox app.
- [Validation](validation.md): the schemas of tool arguments.
- [AI agents](../getting-started/ai-agents.md): help an AI agent write Dox code.
