# Performance mistakes

Dart runs one thing at a time in each isolate. When a request does slow work without an
`await`, every other request on that isolate waits. Check new code against this list.

## Heavy CPU work in a request

Building a PDF, resizing an image or parsing a huge JSON file blocks the isolate.
Run it on a worker isolate:

```dart
// Wrong: blocks the isolate
return buildPdf(order.toJson());

// Right
Future<List<int>> renderPdf(Map<String, dynamic> data) {
  return Dox().compute(() => buildPdf(data));
}
```

The task runs in another isolate. Make it in a small top-level or static function and
pass only plain values (numbers, strings, lists, maps). Do not use a database
connection, the container or a cache store inside it.
`computeWorkers` in `AppConfig` sets the number of workers.

## Password hashing

`Hash.make` and `Hash.verify` block the isolate while bcrypt runs. In request code use
the async methods. They run on a worker:

```dart
String hashed = await Hash.makeAsync(password);
bool ok = await Hash.verifyAsync(password, user.password);
```

Seeders, commands and tests may use the sync methods.

## Sync file calls

```dart
String text = File('data/terms.txt').readAsStringSync(); // Wrong
String text = await File('data/terms.txt').readAsString(); // Right
```

## Awaiting independent work one by one

If two calls do not need each other, start both and wait for both:

```dart
(int, int) counts = await (User().count(), Order().count()).wait;
```

For a list of futures use `Future.wait(futures)`.

## A static Map as a cache

It grows until the memory is full, and each isolate has its own copy. Use the cache
with a time to live:

```dart
Map<String, dynamic> settings = await Cache().remember(
  'settings',
  Duration(minutes: 10),
  loadSettings,
);
```

## A missing await

An async call without `await` loses its error and can end after the response is sent.
Always `await` it. To run work after the response on purpose, use a queue job.

## A new client for every request

An HTTP client or a Redis client opens connections. Make one, register it in the
container and inject it. Do not make one inside a handler.

## A big file in memory

`file.bytes` loads the whole upload. Use `file.stream()` for big files, and return a
stream for a big download. Keep `maxBodySize` and `maxMultipartSize` set in `AppConfig`.

## Timers and listeners that never stop

On server-sent events or a WebSocket, cancel every `Timer.periodic` and every stream
subscription when the client disconnects.

## Strict mode

Strict mode warns about these mistakes in development. It is off by default and costs
nothing when off. The app template turns it on in development:

```dart
AppConfig appConfig = AppConfig(
  strict: StrictConfig(enabled: env.appEnv == 'development'),
  // ...
);
```

Warnings go to stderr with a `[strict]` tag. They say when a route blocked the isolate
for more than `blockLimit` (50 ms by default), when the event loop was blocked, and
when sync `Hash.make`, `Hash.verify` or `Hash.check` ran in the web server.
Fix the code that caused the warning. Do not turn strict mode off to hide it.

Database mistakes (a query in a loop, loading a whole table, a long transaction) are in
the `dox-orm-guide` skill.
