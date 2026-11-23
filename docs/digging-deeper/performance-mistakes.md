---
icon: lucide/triangle-alert
---

# Performance mistakes

These are the mistakes that make a Dox app slow, with the fix for each one, and a strict mode that warns you about the worst of them.

Dart runs one thing at a time in each isolate. When one request does slow work with no `await`, every other request on that isolate waits. For server settings, see [Performance](performance.md).

## Heavy CPU work in a request

A PDF, an image or a huge JSON file keeps the CPU busy. Run the work on a worker isolate with `Dox().compute`:

```dart title="Wrong"
Future<List<int>> invoice(DoxRequest req) async {
  Order order = await Order().findOrFail(req.param['id']);
  return buildPdf(order.toJson()); // blocks the isolate
}
```

```dart title="Right"
Future<List<int>> invoice(DoxRequest req) async {
  Order order = await Order().findOrFail(req.param['id']);
  return renderPdf(order.toJson());
}

Future<List<int>> renderPdf(Map<String, dynamic> data) {
  return Dox().compute(() => buildPdf(data));
}
```

Pass only plain values to the task, like numbers, strings, lists and maps. See [Heavy CPU work](isolate.md#heavy-cpu-work).

## Sync password hashing

`Hash.make` and `Hash.verify` run bcrypt on the isolate, and bcrypt is slow on purpose. In a handler, use the async methods:

```dart title="Wrong"
bool ok = Hash.verify(password, user.password);
```

```dart title="Right"
bool ok = await Hash.verifyAsync(password, user.password);
String hashed = await Hash.makeAsync(password);
```

## Sync file calls

A sync file call stops the isolate until the disk answers. Use the async call:

```dart title="Wrong"
String text = File('data/terms.txt').readAsStringSync();
```

```dart title="Right"
String text = await File('data/terms.txt').readAsString();
```

## Loading a whole table

`all()` and `get()` read every row into memory. On a big table, read one page:

```dart title="Wrong"
List<Order> orders = await Order().all();
```

```dart title="Right"
Pagination<Order> page =
    await Order().orderBy('id').paginate(currentPage: 1, perPage: 50);
```

To work on all rows, use `chunk()`, `lazy()` or `cursor()`:

```dart
await for (Order order in Order().orderBy('id').cursor(chunkSize: 500)) {
  // one row at a time
}
```

See [Paginating results](../database/query-builder.md#paginating-results), [Chunking results](../database/query-builder.md#chunking-results) and [Streaming results](../database/query-builder.md#streaming-results).

## A query inside a loop

This is the **N+1 problem**: 100 posts make 101 queries. `preload()` loads the relation for all rows in one extra query:

```dart title="Wrong"
List<Post> posts = await Post().all();
for (Post post in posts) {
  await post.$getRelation('author'); // one query per post
  User? author = post.author;
}
```

```dart title="Right"
List<Post> posts = await Post().preload('author').get();
for (Post post in posts) {
  User? author = post.author; // already loaded
}
```

## Awaiting independent work one by one

Start two calls that do not need each other at the same time. The total time is then the slowest call:

```dart title="Wrong"
int users = await User().count();
int orders = await Order().count();
```

```dart title="Right"
(int, int) counts = await (User().count(), Order().count()).wait;
```

For a list of futures, use `Future.wait(futures)`.

## A static Map as a cache

A static map that you never clean grows until the memory is full, and each isolate has its own copy. Use the [cache](cache.md) with a time to live:

```dart title="Wrong"
static final Map<String, Object> _settings = <String, Object>{};
```

```dart title="Right"
Map<String, dynamic> settings = await Cache().remember(
  'settings',
  Duration(minutes: 10),
  loadSettings,
);
```

With the `redis` or `database` store, all isolates and servers share the same values.

## Forgetting await

An async call with no `await` loses its error, and it can end after the response is sent:

```dart title="Wrong"
mailer.sendWelcome(user);
```

```dart title="Right"
await mailer.sendWelcome(user);
```

The `unawaited_futures` lint in `analysis_options.yaml` finds these. To answer the client first, use a [queue job with `dispatchAfterResponse`](queue.md).

## A new client for every request

A new HTTP or Redis client in each request opens and closes a connection every time. Make one client and share it:

```dart title="Wrong"
Future<String> rate(DoxRequest req) async {
  HttpClient client = HttpClient();
  // ...
}
```

```dart title="Right"
class RateService {
  RateService(this._client);

  final HttpClient _client;

  Future<String> rate() async {
    // use _client
  }
}
```

Register the client one time in the [container](../the-basic/dependency-injection.md) and inject it.

## A long transaction

A transaction holds one database connection until it ends, so a slow API call inside it can empty the pool. Do the slow call before or after the transaction:

```dart title="Wrong"
await QueryBuilder.transaction(() async {
  await order.save();
  await paymentApi.charge(order); // the connection waits here
});
```

```dart title="Right"
await paymentApi.charge(order);
await QueryBuilder.transaction(() async {
  await order.save();
});
```

## Reading a big file into memory

`bytes` loads the whole upload into memory. Stream it. See [Request](../the-basic/request.md#requestfile) and [Files and big responses](../the-basic/response.md#files-and-big-responses):

```dart title="Wrong"
List<int> data = await file.bytes;
```

```dart title="Right"
Stream<List<int>> data = file.stream();
```

## Timers and listeners that never stop

On a long connection, like a WebSocket, a `Timer.periodic` or a stream listener keeps running after the client leaves. Cancel it when the connection closes:

```dart
StreamSubscription<Event> subscription = events.listen(send);
// when the client disconnects
await subscription.cancel();
```

## Let Dox warn you

**Strict mode** writes a warning for the worst mistakes while you develop. It is off by default.

### Strict mode in Dox

Set `strict` in `AppConfig`, only in development:

```dart title="lib/config/app.dart"
AppConfig appConfig = AppConfig(
  strict: StrictConfig(enabled: Env.appEnv == 'development'),
  // ...
);
```

Warnings go to stderr with a `[strict]` tag. `blockLimit` is how long code may block the isolate, 50 ms by default:

```dart
StrictConfig(enabled: true, blockLimit: Duration(milliseconds: 100))
```

A route that blocks the isolate for too long warns one time:

```text
[strict] GET /invoices/{id} blocked the isolate for 180 ms (limit 50 ms). Other requests on this isolate had to wait. Move heavy CPU work (like bcrypt, PDF or image work) to await Dox().compute(...), and use Hash.makeAsync or Hash.verifyAsync for passwords.
```

Code that blocks the event loop after an `await` warns at most one time in 10 seconds, with no name of the code:

```text
[strict] The event loop of isolate 1 was blocked for about 120 ms (limit 50 ms). Some code ran that long without an await, so other requests had to wait. Move heavy CPU work to await Dox().compute(...).
```

`Hash.make`, `Hash.verify` and `Hash.check` in the web server warn one time for each place in your code:

```text
[strict] Hash.make ran in the web server at AuthController.register (package:my_app/app/http/controllers/auth_controller.dart:21:18). It blocks the isolate while bcrypt runs, so other requests wait. Use await Hash.makeAsync(...) instead.
```

### Strict mode in the ORM

Set `strict` in `DatabaseConfig`:

```dart title="lib/config/database.dart"
DatabaseConfig databaseConfig = DatabaseConfig(
  // ...
  strict: OrmStrict(enabled: appConfig.isDevelopment),
);
```

`nPlusOneCount` (default 5) is how many row by row loads of one relation in about one second give a warning. `maxRows` (default 1000) is how many rows `get()` or `all()` may read. The warnings have a `[db]` tag:

```text
[db] Strict mode: possible N+1 query. The relation "author" of Post was loaded row by row 5 times in a short time. Load it for all rows in one query with preload('author').
```

```text
[db] Strict mode: table "orders" read 25000 rows into memory (the limit is 1000). Use paginate(), chunk(), lazy() or cursor() for big results.
```

## Next steps

- [Performance](performance.md): the benchmark numbers.
- [Isolate](isolate.md): how Dox uses the CPU cores.
- [Cache](cache.md): keep slow results.
