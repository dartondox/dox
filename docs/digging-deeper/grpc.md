---
icon: lucide/network
---

# gRPC

The `dox_grpc` package lets your Dox app serve gRPC services on the same port as your HTTP routes.

Use gRPC when your services send calls to each other. You write the calls one time in a `.proto` file. Each side then gets typed code from this file. gRPC also has streaming: a client and a server can send many messages in one call.

A client in any language can call `dox_grpc`, because it serves standard gRPC. Your Dox middleware runs before each call. Thus, you can use the same auth for your gRPC services and your HTTP routes.

## Installation

Run the setup command in your app:

```bash
dox add grpc
```

The command does these steps:

- It adds `dox_grpc`, `protobuf`, and `grpc` to `pubspec.yaml`. The generated code imports `protobuf` and `grpc`.
- It writes a sample `protos/greeter.proto` file.
- It writes `lib/routes/grpc.dart`. This router registers the [health check](#health-check).
- It adds `APP_HTTP2=true` to `.env` and `.env.example`.

The command does not overwrite a file. It is safe to run the command again. At the end, the command shows the steps that you must do.

To add the package manually, run `dart pub add dox_grpc protobuf grpc`.

### Turn on HTTP/2

gRPC works only over HTTP/2, and [HTTP/2](http2.md) is off by default. Turn on HTTP/2 in the app config:

```dart title="lib/config/app.dart"
AppConfig appConfig = AppConfig(
  http2: true,
  // ...
);
```

The `APP_HTTP2` key in `.env` does not turn on HTTP/2 alone. To use this key, add a `bool? get appHttp2` getter to `AppEnv`. Then set `http2: env.appHttp2 ?? false` in the app config.

Your HTTP routes continue to work on the same port.

## Define a service

### Write the .proto file

A `.proto` file gives the calls of a service and the messages that the calls use. Put the file in the `protos/` folder:

```proto title="protos/greeter.proto"
syntax = "proto3";

package greeter;

service Greeter {
  rpc SayHello (HelloRequest) returns (HelloReply);
  rpc SayHelloMany (HelloRequest) returns (stream HelloReply);
  rpc CollectNames (stream HelloRequest) returns (HelloReply);
  rpc Chat (stream HelloRequest) returns (stream HelloReply);
}

message HelloRequest {
  string name = 1;
}

message HelloReply {
  string message = 1;
}
```

### Generate the Dart code

The `protoc` tool makes Dart code from the `.proto` file. Install `protoc`. For example, run `brew install protobuf`. Then install the Dart plugin of `protoc`. You do this step one time only:

```bash
dart pub global activate protoc_plugin
```

Make sure that `~/.pub-cache/bin` is on your `PATH`. Then `protoc` can find the plugin. Generate the code:

```bash
protoc --dart_out=grpc:lib/generated -Iprotos protos/greeter.proto
```

This command writes the message classes and a `GreeterServiceBase` class to `lib/generated`. Each time you change the `.proto` file, run the command again.

### Write the service

Extend the generated base class. Each `rpc` in the `.proto` file is one method:

```dart title="lib/app/grpc/greeter_service.dart"
import 'package:dox_grpc/dox_grpc.dart';

import '../../generated/greeter.pbgrpc.dart';

class GreeterService extends GreeterServiceBase {
  @override
  Future<HelloReply> sayHello(ServiceCall call, HelloRequest request) async {
    return HelloReply(message: 'Hello ${request.name}');
  }

  // sayHelloMany, collectNames and chat: see "Call types"
}
```

## Register a service

Call `Grpc.register` in a router that has no prefix:

```dart title="lib/routes/grpc.dart"
import 'package:dox_core/dox_core.dart';
import 'package:dox_grpc/dox_grpc.dart';

import '../app/grpc/greeter_service.dart';

class GrpcRouter extends Router {
  @override
  void register() {
    Grpc.register(GreeterService());
  }
}
```

The router must not have a prefix. A gRPC client always calls the path `/<package.Service>/<Method>`, for example `/greeter.Greeter/SayHello`. A prefix changes this path, and then no client can find the service.

Do not use the `api` router, a `Route.group`, or a `Route.prefix`. If the path changes, Dox throws a `StateError` when the app starts.

You can now call the service. For example, use [grpcurl](https://github.com/fullstorydev/grpcurl):

```bash
grpcurl -plaintext -import-path protos -proto greeter.proto \
  -d '{"name": "Ann"}' localhost:3000 greeter.Greeter/SayHello
```

## Call types

gRPC has four types of calls. The position of `stream` in the `.proto` file sets the type.

### Unary calls

A unary call has one request and one reply. The method returns a `Future`:

```dart
@override
Future<HelloReply> sayHello(ServiceCall call, HelloRequest request) async {
  return HelloReply(message: 'Hello ${request.name}');
}
```

### Server streaming

The client sends one request and gets many replies. The method returns a `Stream`. Use `async*` and `yield`:

```dart
@override
Stream<HelloReply> sayHelloMany(ServiceCall call, HelloRequest request) async* {
  for (int i = 1; i <= 3; i++) {
    if (call.isCanceled) return;
    yield HelloReply(message: 'Hello ${request.name} $i');
  }
}
```

The `call.isCanceled` check stops the work when the client cancels the call. See [Deadlines and cancelled calls](#deadlines-and-cancelled-calls).

### Client streaming

The client sends many requests and gets one reply. The method gets a `Stream` of requests:

```dart
@override
Future<HelloReply> collectNames(
  ServiceCall call,
  Stream<HelloRequest> request,
) async {
  List<String> names = <String>[];
  await for (HelloRequest item in request) {
    names.add(item.name);
  }
  return HelloReply(message: 'Hello ${names.join(', ')}');
}
```

### Bidirectional streaming

The client and the server both send many messages. The method gets a `Stream` and returns a `Stream`:

```dart
@override
Stream<HelloReply> chat(ServiceCall call, Stream<HelloRequest> request) async* {
  await for (HelloRequest item in request) {
    yield HelloReply(message: 'Hello ${item.name}');
  }
}
```

## Return errors

To stop a call with an error, throw a `GrpcException`. The first argument is a value of the `GrpcStatus` enum. This enum has all the gRPC status codes. The second argument is the message for the client:

```dart
throw GrpcException(GrpcStatus.notFound, 'No user 5');
```

If your method throws a different error, the call stops with `INTERNAL`. Dox sends the error to your `ExceptionHandler`, the same as for HTTP routes. The client sees the error text only when `APP_ENV` is `development` or `local`.

A call to a service or a method that does not exist gets `UNIMPLEMENTED`.

## Metadata

Metadata is the gRPC name for headers. The `call` argument gives you three maps:

- `call.clientMetadata`: the headers that the client sent.
- `call.headers`: the headers that you send back. Set them before the first reply.
- `call.trailers`: the headers that you send at the end of the call.

```dart
@override
Future<HelloReply> sayHello(ServiceCall call, HelloRequest request) async {
  String? language = call.clientMetadata!['accept-language'];
  call.headers!['x-served-by'] = 'greeter';
  call.trailers!['x-done'] = 'yes';
  return HelloReply(message: 'Hello ${request.name} ($language)');
}
```

You must use `!`, because the maps are nullable in the `ServiceCall` type.

## Deadlines and cancelled calls

A client can set a deadline for a call. When the deadline passes, Dox stops the call with `DEADLINE_EXCEEDED`. A client can also cancel a call or lose its connection.

In these cases, your method can continue to run. If your method runs for a long time, make it read `call.isCanceled` and `call.isTimedOut`, and stop:

```dart
@override
Stream<HelloReply> sayHelloMany(ServiceCall call, HelloRequest request) async* {
  while (!call.isCanceled && !call.isTimedOut) {
    yield HelloReply(message: 'Hello ${request.name}');
    await Future<void>.delayed(Duration(seconds: 1));
  }
}
```

`call.deadline` is the time of the deadline. It is `null` if the client did not set a deadline. When the client cancels a streaming call, the request stream also stops.

## Middleware

Most services must know the caller. The middleware of the router runs before each call. Add your auth middleware there:

```dart title="lib/routes/grpc.dart"
import '../app/http/middleware/auth.middleware.dart'; // dox make:middleware auth

class GrpcRouter extends Router {
  @override
  List<dynamic> get middleware => <dynamic>[AuthMiddleware()];

  @override
  void register() {
    Grpc.register(GreeterService());
  }
}
```

A gRPC client sends its token as metadata. The middleware reads the token the same as an HTTP header:

```dart title="lib/app/http/middleware/auth.middleware.dart"
class AuthMiddleware implements IDoxMiddleware {
  @override
  dynamic handle(IDoxRequest req) {
    String token = Env.get<String>('API_TOKEN');
    if (!Hash.equals(req.header('authorization') ?? '', 'Bearer $token')) {
      throw HttpStatusException(401, message: 'Bad token');
    }
    return req;
  }
}
```

When a middleware throws an HTTP error, the client gets the related gRPC status and the message. For example, `401` becomes `UNAUTHENTICATED`. See [the full list](#http-errors-and-grpc-statuses).

### Add middleware to some services

If only some services of a router need a middleware, put them in `Route.middleware`:

```dart
Route.middleware(<dynamic>[AuthMiddleware()], () {
  Grpc.register(GreeterService());
});
```

The first `Grpc.register` call of your app must not be in `Route.middleware`. To obey this rule easily, register the [health check](#health-check) first.

## Options

The default values are correct for most services. To change them for one service, give a `GrpcOptions`:

```dart
Grpc.register(
  GreeterService(),
  options: GrpcOptions(
    maxReceiveMessageSize: 16 * 1024 * 1024,
    idleTimeout: Duration(minutes: 5),
  ),
);
```

### Set the maximum message size

`maxReceiveMessageSize` is the maximum size of a request message, in bytes. `maxSendMessageSize` is the maximum size of a reply message. Both are 4 MiB by default. If a message is larger, the call stops with `RESOURCE_EXHAUSTED`.

```dart
GrpcOptions(
  maxReceiveMessageSize: 16 * 1024 * 1024,
  maxSendMessageSize: 16 * 1024 * 1024,
)
```

### Compress replies

Set `gzipResponses` to compress replies with gzip for clients that accept gzip. It is off by default, because gzip uses CPU time for each message, and most gRPC messages are small. Turn it on when your replies are large and contain text:

```dart
GrpcOptions(gzipResponses: true)
```

Dox always reads gzip requests, with or without this option.

### Stop idle calls

A client can open a call and then not read the reply. To release these calls, set `idleTimeout`. If no message goes in or out for that time, the call stops with `DEADLINE_EXCEEDED`:

```dart
GrpcOptions(idleTimeout: Duration(minutes: 5))
```

It is off by default. Set `idleTimeout` longer than your slowest method, because the time also counts while your method works and sends no message.

## Health check

Load balancers and Kubernetes ask a server for its health before they send calls to it. `HealthService` answers them. It is the standard `grpc.health.v1.Health` service, with `Check` and `Watch`.

`dox add grpc` registers it in `lib/routes/grpc.dart`. Do not put the health service behind auth middleware, because a load balancer has no token. If your services need auth, register the health service in a separate router:

```dart title="lib/routes/grpc_health_router.dart"
import 'package:dox_core/dox_core.dart';
import 'package:dox_grpc/dox_grpc.dart';

class GrpcHealthRouter extends Router {
  @override
  void register() {
    Grpc.register(HealthService());
  }
}
```

The health service must be the first `Grpc.register` call of the app. In the app config, put this router in `routers` before the other gRPC routers. See [Routers and providers](../the-basic/dependency-injection.md#routers-and-providers).

### Set the status of a service

The full server has the empty name `''`. Its status at start is `SERVING`. To give the status of one service by its name, keep the `HealthService` object and call `setStatus`:

```dart
HealthService health = HealthService();
Grpc.register(health);

health.setStatus('greeter.Greeter', ServingStatus.SERVING);
```

When the service cannot work, call `setStatus` again with `ServingStatus.NOT_SERVING`. For example, do this when the database of the service is down. All isolates get the change.

## Services and isolates

Dox runs your app in many [isolates](isolate.md). Each isolate gets its own copy of your service. You cannot copy a database connection, a socket, or a `ReceivePort` to a different isolate. Thus, do not create these objects when you register the service.

Create them on the first call. Then the isolate that uses the object also creates it:

```dart
class GreeterService extends GreeterServiceBase {
  HttpClient? _client;

  // made on the first call, in the isolate that runs the call
  HttpClient get client => _client ??= HttpClient();

  @override
  Future<HelloReply> sayHello(ServiceCall call, HelloRequest request) async {
    // use client here
    return HelloReply(message: 'Hello ${request.name}');
  }
}
```

## Deployment

gRPC runs on the [native server](native-server.md). Build your app with `dox build`. See [Deployment](deployment.md#build).

Dox does not have TLS. Put a proxy in front of the app. The proxy does the TLS and sends h2c to Dox. h2c is plain HTTP/2 without TLS.

With nginx, use `grpc_pass` for the gRPC paths. With Caddy, use `h2c://` in `reverse_proxy`. For the full config, see [Deployment: HTTP/2 and gRPC](deployment.md#http2-and-grpc).

## Benchmark

On one core, `dox_grpc` does the most small calls. Small calls are the most usual type of gRPC call.

<div class="dox-bench dox-bench--simple" markdown>

<p class="dox-bench__title">One core: the most small calls</p>
<p class="dox-bench__sub">Unary calls with a small message. Every server has one core: Dox one isolate, grpc-go <code>GOMAXPROCS=1</code>.</p>

<div class="dox-bench__grid">
  <span></span><span></span>
  <span class="dox-bench__head">calls/s</span>

  <div class="dox-bench__row dox-bench__row--win">
    <span class="dox-bench__name"><strong>Dox</strong><span>dox_grpc</span></span>
    <span class="dox-bench__track"><span class="dox-bench__bar" style="--w: 100%"></span></span>
    <span class="dox-bench__num">48,700<span class="dox-bench__vs">fastest</span></span>
  </div>
  <div class="dox-bench__row">
    <span class="dox-bench__name"><strong>Go</strong><span>grpc-go</span></span>
    <span class="dox-bench__track"><span class="dox-bench__bar" style="--w: 90.3%"></span></span>
    <span class="dox-bench__num">44,000<span class="dox-bench__vs">1.1× slower</span></span>
  </div>
  <div class="dox-bench__row">
    <span class="dox-bench__name"><strong>dart:io</strong><span>package:grpc</span></span>
    <span class="dox-bench__track"><span class="dox-bench__bar" style="--w: 72.5%"></span></span>
    <span class="dox-bench__num">35,300<span class="dox-bench__vs">1.4× slower</span></span>
  </div>
</div>

<p class="dox-bench__foot"><span>Linux · 16 connections · 128 calls in flight · ghz · median of 3 runs</span></p>

</div>

Dox is not the fastest in all tests. With large messages and with streaming, grpc-go is faster on one core. `dox_grpc` is faster than `package:grpc` in all three tests.

Calls a second on one core:

| Test                                   | `dox_grpc` | `package:grpc` | grpc-go |
| -------------------------------------- | ---------: | -------------: | ------: |
| Unary, small message                   | 48,700     | 35,300         | 44,000  |
| Unary, 100 KB reply                    | 14,600     | 11,400         | 17,200  |
| Server streaming, 100 messages of 1 KB | 4,390      | 2,010          | 6,240   |

On four cores, Dox runs four isolates. Then the two servers are almost equal:

| Test                                   | `dox_grpc` | grpc-go |
| -------------------------------------- | ---------: | ------: |
| Unary, small message                   | 56,500     | 56,800  |
| Unary, 100 KB reply                    | 19,300     | 21,000  |
| Server streaming, 100 messages of 1 KB | 7,550      | 7,650   |

For small calls, both servers stop at approximately 57,000 calls a second. This number is near the limit of the client on 4 cores. Both servers can possibly do more.

### Test setup

- All servers run the same service: the gRPC interop `TestService`.
- The Dart servers are AOT builds. The build command is `dart build cli`.
- `package:grpc` runs on `dart:io` and has one isolate. For this reason, it is only in the one-core table.
- All tests ran in Linux containers on one machine with 8 cores. The server used 4 cores. The client, [ghz](https://ghz.sh), used the other 4 cores.
- The client used 16 connections. For small calls, it kept 128 calls open at the same time. For the other two tests, it kept 32 calls open.
- Each number is the median of 3 runs. Each run took 10 seconds, after a warm up of 3 seconds.

## Details

This section gives special cases. Most apps do not need it.

### HTTP errors and gRPC statuses

| HTTP error | gRPC status |
| --- | --- |
| 400, 422 | `INVALID_ARGUMENT` |
| 401 | `UNAUTHENTICATED` |
| 403 | `PERMISSION_DENIED` |
| 404 | `NOT_FOUND` |
| 408, 504 | `DEADLINE_EXCEEDED` |
| 409 | `ABORTED` |
| 413, 429 | `RESOURCE_EXHAUSTED` |
| 501 | `UNIMPLEMENTED` |
| 502, 503 | `UNAVAILABLE` |
| other 4xx | `FAILED_PRECONDITION` |
| other 5xx | `INTERNAL` |

Dox shows the message of a 5xx error only when `APP_ENV` is `development` or `local`.

### Other cases

- `GrpcException` takes a list of protobuf messages as a third argument. Dox sends them to the client as error details in `grpc-status-details-bin`.
- A `GrpcError` from `package:grpc` works the same as a `GrpcException`.
- `call.clientMetadata` does not contain the `grpc-*` headers.
- A metadata value with a name that ends in `-bin` is base64 text. `GrpcWire.decodeBinary` gives its bytes. `GrpcWire.encodeBinary` makes a value from bytes.
- `maxReceiveMessageSize` also applies to the size of a gzip message after Dox decompresses it.
- gRPC routes skip the `RequestTimeout` middleware. Thus, Dox does not stop a long stream.
- If the first `Grpc.register` call is in `Route.middleware`, Dox throws a `StateError` when the app starts.
- `health.clearStatus(name)` removes the status of a service. A `Check` for a name with no status gets `NOT_FOUND`.
