# Isolate

Dox runs your HTTP server on many isolates (threads) at once. All of them
listen on the same port (`HttpServer.bind(..., shared: true)`), and the OS
spreads the connections between them.

## How many

By default Dox starts one isolate per CPU core (`Platform.numberOfProcessors`).
So one process uses the whole machine.

To change it, set `totalIsolate` in `lib/config/app.dart`, or set
`APP_TOTAL_ISOLATE` in the environment.

```dart
totalIsolate: Env.get<int>('APP_TOTAL_ISOLATE', Platform.numberOfProcessors),
```

Use fewer isolates when:

- the machine also runs the database or other heavy work, or
- you run websocket rooms without a Redis adapter. Each isolate has its own
  memory, so a room only reaches clients on the same isolate. Use `1` then.

## What each isolate does

Each isolate has its own memory. At start, every isolate:

1. runs the `setup()` of each service in `services` (for example it opens
   its own database pool),
2. registers the routes, and reads the parameter types of each controller once.

This is cheap: it happens once at start, not per request. Keep `setup()`
light. Open connections there, but do not load big data into memory, because
it is loaded once per isolate.

## When an isolate crashes

- An error in a request is caught. Dox sends a 500 and keeps going.
- A stray async error (for example a future that nobody awaits) is caught and
  passed to `errorHandler`. The isolate keeps running.
- If a worker isolate still dies, Dox prints `[dox] isolate N exited,
  restarting` with the error to stderr, and starts a new one after 1 second.
- If the main isolate dies, the process exits with a non-zero code. Let your
  supervisor (Docker `restart:`, systemd `Restart=always`) start it again.
  See [Deployment](deployment.md#keep-it-running).
