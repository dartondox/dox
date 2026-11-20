---
icon: lucide/network
---

# gRPC

The `dox_grpc` package lets your Dox app serve gRPC services on the same port as your HTTP routes.

gRPC is a good fit when services call each other. You describe the calls once in a `.proto` file, and each side gets typed code from it. It also has streaming, so a client and a server can send many messages on one call.

`dox_grpc` serves standard gRPC, so a client in any language can call it. Your Dox middleware runs before each call, so you can use the same auth as for your HTTP routes.

## Installation

Add the package. Because the generated code imports `protobuf` and `grpc`, add them too:

```bash
dart pub add dox_grpc protobuf grpc
```

### Turning on HTTP/2

gRPC only works over HTTP/2, and [HTTP/2](http2.md) is off by default. So turn it on in the app config:

```dart title="lib/config/app.dart"
AppConfig appConfig = AppConfig(
  http2: true,
  // ...
);
```

Your normal HTTP routes keep working on the same port.

## Defining a service

### Writing the .proto file

A `.proto` file lists the calls of a service and the messages they use. Put it in a `protos/` folder:

```proto title="protos/greeter.proto"
syntax = "proto3";

package helloworld;

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

### Generating the Dart code

The `protoc` tool turns the `.proto` file into Dart code. Install `protoc` (for example with `brew install protobuf`), and then install its Dart plugin once:

```bash
dart pub global activate protoc_plugin
```

Make sure `~/.pub-cache/bin` is on your `PATH`, so `protoc` can find the plugin. Then generate the code:

```bash
protoc --dart_out=grpc:lib/generated -Iprotos protos/greeter.proto
```

This writes the message classes and a `GreeterServiceBase` class to `lib/generated`. Run it again each time you change the `.proto` file.

### Writing the service

Extend the generated base class. Each `rpc` of the `.proto` file is one method:

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

## Registering a service

Call `Grpc.register` in a router that has no prefix:

```dart title="lib/routes/grpc_router.dart"
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

The router must have no prefix, because a gRPC client always calls the path `/<package.Service>/<Method>`, like `/helloworld.Greeter/SayHello`. A prefix would change the path, and no client could reach the service. So do not use the `api` router, a `Route.group` or a `Route.prefix`. If the path did change, Dox throws a `StateError` when the app starts.

You can now call the service, for example with [grpcurl](https://github.com/fullstorydev/grpcurl):

```bash
grpcurl -plaintext -import-path protos -proto greeter.proto \
  -d '{"name": "Ann"}' localhost:3000 helloworld.Greeter/SayHello
```

## Call types

gRPC has four kinds of calls. The kind depends on where you wrote `stream` in the `.proto` file.

### Unary calls

A unary call has one request and one reply. The method returns a `Future`:

```dart
@override
Future<HelloReply> sayHello(ServiceCall call, HelloRequest request) async {
  return HelloReply(message: 'Hello ${request.name}');
}
```

### Server streaming

The client sends one request and gets many replies. The method returns a `Stream`, so use `async*` and `yield`:

```dart
@override
Stream<HelloReply> sayHelloMany(ServiceCall call, HelloRequest request) async* {
  for (int i = 1; i <= 3; i++) {
    if (call.isCanceled) return;
    yield HelloReply(message: 'Hello ${request.name} $i');
  }
}
```

The `call.isCanceled` check stops the work when the client is gone. See [Deadlines and cancellation](#deadlines-and-cancellation).

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

Both sides send many messages. The method gets a `Stream` and returns a `Stream`:

```dart
@override
Stream<HelloReply> chat(ServiceCall call, Stream<HelloRequest> request) async* {
  await for (HelloRequest item in request) {
    yield HelloReply(message: 'Hello ${item.name}');
  }
}
```

## Returning errors

To end a call with an error, throw a `GrpcException`. The first argument is a value of the `GrpcStatus` enum, which has all gRPC status codes. The second is the message for the client:

```dart
throw GrpcException(GrpcStatus.notFound, 'No user 5');
```

If your method throws any other error, the call ends with `INTERNAL`. Dox sends the error to your `ExceptionHandler`, like the errors of HTTP routes. The client sees the error text only when `APP_ENV` is `development` or `local`.

A call to a service or a method that does not exist gets `UNIMPLEMENTED`.

## Metadata

Metadata is the gRPC name for headers. The `call` argument gives you three maps:

- `call.clientMetadata`: the headers the client sent.
- `call.headers`: the headers you send back. Set them before the first reply.
- `call.trailers`: the headers you send at the end of the call.

```dart
@override
Future<HelloReply> sayHello(ServiceCall call, HelloRequest request) async {
  String? language = call.clientMetadata!['accept-language'];
  call.headers!['x-served-by'] = 'greeter';
  call.trailers!['x-done'] = 'yes';
  return HelloReply(message: 'Hello ${request.name} ($language)');
}
```

The maps are nullable in the `ServiceCall` type, so you need the `!`.

## Deadlines and cancellation

A client can set a deadline for a call. When it passes, Dox ends the call with `DEADLINE_EXCEEDED`. A client can also cancel a call, or lose its connection.

In both cases your method may still be running. So a method that works for a long time should check the call and stop:

```dart
@override
Stream<HelloReply> sayHelloMany(ServiceCall call, HelloRequest request) async* {
  while (!call.isCanceled && !call.isTimedOut) {
    yield HelloReply(message: 'Hello ${request.name}');
    await Future<void>.delayed(Duration(seconds: 1));
  }
}
```

`call.deadline` is the time of the deadline, or `null` if the client set none. When the client cancels, the request stream of a streaming call also ends.

## Middleware

Most services need to know who is calling. The middleware of the router runs before each call, so add your auth middleware there:

```dart title="lib/routes/grpc_router.dart"
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

A gRPC client sends its token as metadata. The middleware reads it like any HTTP header:

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

When a middleware throws an HTTP error, the client gets the matching gRPC status with the message. For example, `401` becomes `UNAUTHENTICATED`. See [the full list](#http-errors-as-grpc-statuses).

### Middleware for one service

If only some services of a router need a middleware, wrap them in `Route.middleware`:

```dart
Route.middleware(<dynamic>[AuthMiddleware()], () {
  Grpc.register(GreeterService());
});
```

The first `Grpc.register` of your app must not be inside `Route.middleware`. The easy way to follow this rule is to register the [health check](#health-check) first.

## Options

The defaults fit most services. To change them for one service, pass a `GrpcOptions`:

```dart
Grpc.register(
  GreeterService(),
  options: GrpcOptions(
    maxReceiveMessageSize: 16 * 1024 * 1024,
    idleTimeout: Duration(minutes: 5),
  ),
);
```

### Limiting the message size

`maxReceiveMessageSize` is the biggest request message in bytes, and `maxSendMessageSize` is the biggest reply message. Both are 4 MiB by default. A bigger message ends the call with `RESOURCE_EXHAUSTED`.

```dart
GrpcOptions(
  maxReceiveMessageSize: 16 * 1024 * 1024,
  maxSendMessageSize: 16 * 1024 * 1024,
)
```

### Compressing replies

Set `gzipResponses` to send replies with gzip to clients that accept it. It is off by default, because gzip costs CPU on every message and most gRPC messages are small. Turn it on when your replies are big text:

```dart
GrpcOptions(gzipResponses: true)
```

Requests with gzip are always read, with or without this option.

### Ending quiet calls

A client can open a call and then never read the answer. To free such calls, set `idleTimeout`. A call with no message in or out for that long ends with `DEADLINE_EXCEEDED`:

```dart
GrpcOptions(idleTimeout: Duration(minutes: 5))
```

It is off by default. The time also runs while your own method works and sends nothing, so set it longer than your slowest method.

## Health check

Load balancers and Kubernetes ask a server if it is healthy before they send it calls. `HealthService` answers them. It is the standard `grpc.health.v1.Health` service, with `Check` and `Watch`.

A load balancer has no token. So register the health service in its own router, with no auth middleware:

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

The health service must be the first `Grpc.register` of the app. So list your routers in `routers` of the app config, with this one before the other gRPC routers. See [Routers and providers](../the-basic/dependency-injection.md#routers-and-providers).

### Setting the status of a service

The whole server has the empty name `''`, and it starts as `SERVING`. To report one service by its name, keep the `HealthService` and call `setStatus`:

```dart
HealthService health = HealthService();
Grpc.register(health);

health.setStatus('helloworld.Greeter', ServingStatus.SERVING);
```

Call `setStatus` again with `ServingStatus.NOT_SERVING` when the service can not work, for example when its database is down. The change reaches all isolates.

## Services and isolates

Dox runs your app in many [isolates](isolate.md), and each isolate gets its own copy of your service. A database connection, a socket or a `ReceivePort` can not be copied to another isolate. So do not create one when you register the service.

Create it on the first call. It is then made inside the isolate that uses it:

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

gRPC runs on the [native server](native-server.md), so build your app with `dox build`. See [Deployment](deployment.md#build).

Dox has no TLS, so put a proxy in front of the app. The proxy does TLS and talks plain HTTP/2 (h2c) to Dox. With nginx, use `grpc_pass` for the gRPC paths. With Caddy, use `h2c://` in `reverse_proxy`.

See [Deployment: HTTP/2 and gRPC](deployment.md#http2-and-grpc) for the full config.

## Benchmark

On one core, `dox_grpc` handles the most small calls. These are the most common kind of gRPC call.

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

Dox does not win every test. With big messages and with streaming, grpc-go is faster on one core. `dox_grpc` is faster than `package:grpc` in all three tests.

Calls a second on one core:

| Test                                   | `dox_grpc` | `package:grpc` | grpc-go |
| -------------------------------------- | ---------: | -------------: | ------: |
| Unary, small message                   | 48,700     | 35,300         | 44,000  |
| Unary, 100 KB reply                    | 14,600     | 11,400         | 17,200  |
| Server streaming, 100 messages of 1 KB | 4,390      | 2,010          | 6,240   |

On four cores, Dox runs four isolates, and the two servers are about even:

| Test                                   | `dox_grpc` | grpc-go |
| -------------------------------------- | ---------: | ------: |
| Unary, small message                   | 56,500     | 56,800  |
| Unary, 100 KB reply                    | 19,300     | 21,000  |
| Server streaming, 100 messages of 1 KB | 7,550      | 7,650   |

The small calls stop at about 57,000 a second for both servers. That is near the limit of the client on 4 cores, so both servers may be able to do more.

### How it was run

- Every server runs the same service: the gRPC interop `TestService`.
- The Dart servers are AOT builds (`dart build cli`). `package:grpc` runs on `dart:io` and has one isolate, so it is only in the one-core table.
- Everything ran in Linux containers on one 8-core machine. The server had 4 cores, and the client ([ghz](https://ghz.sh)) had the other 4.
- The client used 16 connections. It kept 128 calls in flight for the small calls, and 32 for the other two tests.
- Each number is the median of 3 runs of 10 seconds, after 3 seconds of warm up.

## Details

This section is for special cases. Most apps do not need it.

### HTTP errors as gRPC statuses

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

The message of a 5xx error is hidden unless `APP_ENV` is `development` or `local`.

### Other cases

- `GrpcException` takes a list of protobuf messages as a third argument. They go to the client as error details (`grpc-status-details-bin`).
- A `GrpcError` from `package:grpc` works the same as a `GrpcException`.
- `call.clientMetadata` does not have the `grpc-*` headers.
- A metadata value whose name ends in `-bin` is base64 text. `GrpcWire.decodeBinary` gives you its bytes, and `GrpcWire.encodeBinary` makes one.
- `maxReceiveMessageSize` also counts the size of a gzip message after unzip.
- gRPC routes skip the `RequestTimeout` middleware, so a long stream is not cut.
- If the first `Grpc.register` is inside `Route.middleware`, Dox throws a `StateError` when the app starts.
- `health.clearStatus(name)` removes the status of a service. A `Check` for a name with no status gets `NOT_FOUND`.
