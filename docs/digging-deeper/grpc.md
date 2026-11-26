---
icon: lucide/network
---

# gRPC

gRPC lets your services call each other with typed messages, on the same port as your HTTP routes.

You write the calls one time in a `.proto` file, and each side gets typed code from it. A client in any language can call your app.

## Setup

Run the setup command in your app:

```bash
dox add grpc
```

It adds the packages, a sample `protos/greeter.proto` file, `lib/routes/grpc.dart` and `APP_HTTP2=true` in `.env`. To add the packages yourself, run `dart pub add dox_grpc protobuf grpc`.

gRPC works only over [HTTP/2](http2.md). A new app turns it on from the `APP_HTTP2` key:

```dart title="lib/config/app.dart"
AppConfig appConfig = AppConfig(
  http2: env.appHttp2 ?? false,
  // ...
);
```

If your `AppEnv` has no `appHttp2` getter, add `bool? get appHttp2;` and run `dart run build_runner build`. Or set `http2: true`.

### Options

Give a `GrpcOptions` to `Grpc.register` to change the limits of one service:

| Option | Default | What it does |
| --- | --- | --- |
| `maxReceiveMessageSize` | 4 MiB | The largest request message, also after unzip. |
| `maxSendMessageSize` | 4 MiB | The largest reply message. |
| `gzipResponses` | false | Gzip the replies for clients that accept gzip. |
| `idleTimeout` | 5 minutes | Stop a call with no message in or out for this time. null means no limit. |

A bigger message stops the call with `RESOURCE_EXHAUSTED`. An idle call stops with `DEADLINE_EXCEEDED`. See [Changing the options](#changing-the-options).

## Write the .proto file

A `.proto` file gives the calls of a service and their messages. The setup command wrote this sample:

```proto title="protos/greeter.proto"
syntax = "proto3";

package greeter;

service Greeter {
  rpc SayHello (HelloRequest) returns (HelloReply);
}

message HelloRequest {
  string name = 1;
}

message HelloReply {
  string message = 1;
}
```

## Generate the Dart code

Install `protoc` and its Dart plugin one time. `~/.pub-cache/bin` must be on your `PATH`:

```bash
brew install protobuf
dart pub global activate protoc_plugin
```

Generate the code. Do this again after each change to the `.proto` file:

```bash
mkdir -p lib/generated
protoc --dart_out=grpc:lib/generated -Iprotos protos/greeter.proto
```

It writes the message classes and a `GreeterServiceBase` class to `lib/generated`.

## Write the service

Extend the generated base class. Each `rpc` of the `.proto` file is one method:

```dart title="lib/app/grpc/greeter_service.dart"
import 'package:dox_grpc/dox_grpc.dart';

import '../../generated/greeter.pbgrpc.dart';

class GreeterService extends GreeterServiceBase {
  @override
  Future<HelloReply> sayHello(
      ServiceCall call, HelloRequest request) async {
    return HelloReply(message: 'Hello ${request.name}');
  }
}
```

## Register the service

Call `Grpc.register` in the router that the setup command wrote. Keep the [health check](#health-check) as the first call:

```dart title="lib/routes/grpc.dart"
import 'package:dox_core/dox_core.dart';
import 'package:dox_grpc/dox_grpc.dart';

import '../app/grpc/greeter_service.dart';

class GrpcRouter extends Router {
  @override
  void register() {
    Grpc.register(HealthService());
    Grpc.register(GreeterService());
  }
}
```

Run `dart run build_runner build` and start the app again.

The router must have no prefix, because a gRPC client always calls `/<package.Service>/<Method>`. So do not use the `api` router or a `Route.group`. A changed path throws a `StateError` at start.

## Call the service

Test a call with [grpcurl](https://github.com/fullstorydev/grpcurl). Give it the `.proto` file, because Dox has no server reflection:

```bash
grpcurl -plaintext -import-path protos -proto greeter.proto \
  -d '{"name": "Ann"}' localhost:3000 greeter.Greeter/SayHello
```

The reply is `{ "message": "Hello Ann" }`.

## Add auth

Your Dox middleware runs before each call. Put the services that need a login in `Route.middleware`, and keep the health check out of it:

```dart title="lib/routes/grpc.dart"
class GrpcRouter extends Router {
  @override
  void register() {
    Grpc.register(HealthService());

    Route.middleware(<dynamic>[AuthMiddleware()], () {
      Grpc.register(GreeterService());
    });
  }
}
```

A client sends its token as metadata. The middleware reads it as a header:

```dart title="lib/app/http/middleware/auth.middleware.dart"
class AuthMiddleware implements IDoxMiddleware {
  @override
  dynamic handle(IDoxRequest req) {
    String token = Env.get<String>('API_TOKEN');
    String sent = req.header('authorization') ?? '';
    if (!Hash.equals(sent, 'Bearer $token')) {
      throw HttpStatusException(401, message: 'Bad token');
    }
    return req;
  }
}
```

The client gets the gRPC status of the HTTP error, so 401 becomes `UNAUTHENTICATED`. See [HTTP errors and gRPC statuses](#http-errors-and-grpc-statuses).

### Middleware for a full router

Set the `middleware` of the router when all its services need it:

```dart title="lib/routes/grpc.dart"
class GrpcRouter extends Router {
  @override
  List<dynamic> get middleware => <dynamic>[AuthMiddleware()];

  @override
  void register() {
    Grpc.register(GreeterService());
  }
}
```

Then register the health check in a router with no middleware, and put it first in `routers` of the app config. See [Routers and providers](../the-basic/dependency-injection.md#routers-and-providers). The first `Grpc.register` of the app in `Route.middleware` throws a `StateError` at start.

## Call types

gRPC has four types of calls. The place of `stream` in the `.proto` file sets the type:

```proto title="protos/greeter.proto"
service Greeter {
  rpc SayHello (HelloRequest) returns (HelloReply);
  rpc SayHelloMany (HelloRequest) returns (stream HelloReply);
  rpc CollectNames (stream HelloRequest) returns (HelloReply);
  rpc Chat (stream HelloRequest) returns (stream HelloReply);
}
```

### Unary calls

One request and one reply. The method returns a `Future`:

```dart
@override
Future<HelloReply> sayHello(ServiceCall call, HelloRequest request) async {
  return HelloReply(message: 'Hello ${request.name}');
}
```

### Server streaming

One request and many replies. The method returns a `Stream`:

```dart
@override
Stream<HelloReply> sayHelloMany(
    ServiceCall call, HelloRequest request) async* {
  for (int i = 1; i <= 3; i++) {
    if (call.isCanceled) return;
    yield HelloReply(message: 'Hello ${request.name} $i');
  }
}
```

### Client streaming

Many requests and one reply. The method gets a `Stream` of requests:

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

Many requests and many replies. The method gets a `Stream` and returns a `Stream`:

```dart
@override
Stream<HelloReply> chat(
    ServiceCall call, Stream<HelloRequest> request) async* {
  await for (HelloRequest item in request) {
    yield HelloReply(message: 'Hello ${item.name}');
  }
}
```

## Return errors

Throw a `GrpcException` with a `GrpcStatus` and a message for the client:

```dart
throw GrpcException(GrpcStatus.notFound, 'No user 5');
```

The third argument is a list of protobuf messages. The client gets them as error details. A `GrpcError` from `package:grpc` also works.

Any other error stops the call with `INTERNAL` and goes to your exception handler. The client sees its text only when `APP_ENV` is `development` or `local`. A call to an unknown service or method gets `UNIMPLEMENTED`.

### Status codes

`GrpcStatus` has the 17 gRPC status codes. `code` is the number, `fromCode` gives the status of a number, and `fromHttp` gives the status of an HTTP error:

```dart
int code = GrpcStatus.notFound.code; // 5
GrpcStatus status = GrpcStatus.fromHttp(401); // unauthenticated
```

### HTTP errors and gRPC statuses

Dox changes an HTTP error of a middleware to a gRPC status:

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

The client also gets the message of the error. The message of a 5xx error shows only when `APP_ENV` is `development` or `local`.

## Metadata

**Metadata** is the gRPC name for headers. `call.clientMetadata` has the headers of the client, with no `grpc-*` headers. Set `call.headers` before the first reply, and `call.trailers` for the end of the call:

```dart
@override
Future<HelloReply> sayHello(ServiceCall call, HelloRequest request) async {
  String? language = call.clientMetadata!['accept-language'];
  call.headers!['x-served-by'] = 'greeter';
  call.trailers!['x-done'] = 'yes';
  return HelloReply(message: 'Hello ${request.name} ($language)');
}
```

The maps are nullable in the `ServiceCall` type, so use `!`.

### Binary metadata

A value with a name that ends in `-bin` is base64 text. `GrpcWire.decodeBinary` gives its bytes, and `GrpcWire.encodeBinary` makes a value from bytes:

```dart
Uint8List bytes = GrpcWire.decodeBinary(call.clientMetadata!['trace-bin']!);
call.trailers!['trace-bin'] = GrpcWire.encodeBinary(bytes);
```

## Deadlines and cancelled calls

When the deadline of the client passes, Dox stops the call with `DEADLINE_EXCEEDED`. Your method can still run, so a long method must check `call.isCanceled` and `call.isTimedOut`:

```dart
@override
Stream<HelloReply> sayHelloMany(
    ServiceCall call, HelloRequest request) async* {
  while (!call.isCanceled && !call.isTimedOut) {
    yield HelloReply(message: 'Hello ${request.name}');
    await Future<void>.delayed(Duration(seconds: 1));
  }
}
```

`call.deadline` is the time of the deadline, or null. gRPC routes skip the `RequestTimeout` middleware, so a long stream does not stop.

## Changing the options

Give a `GrpcOptions` to `Grpc.register`. All options are in [Options](#options):

```dart
Grpc.register(
  GreeterService(),
  options: GrpcOptions(
    maxReceiveMessageSize: 16 * 1024 * 1024,
    maxSendMessageSize: 16 * 1024 * 1024,
    gzipResponses: true,
    idleTimeout: Duration(minutes: 30),
  ),
);
```

Set `idleTimeout` longer than your slowest method, because the time also counts while your method sends no message. A quiet `Watch` stream also stops, so send a message from time to time. Dox always reads gzip requests.

## Health check

`HealthService` is the standard `grpc.health.v1.Health` service, with `Check` and `Watch`. Load balancers and Kubernetes use it. Do not put it behind auth middleware, because a load balancer has no token.

### Set the status of a service

The full server has the empty name `''`, and it starts as `SERVING`. Keep the `HealthService` object to set the status of one service in all isolates:

```dart
HealthService health = HealthService();
Grpc.register(health);

health.setStatus('greeter.Greeter', ServingStatus.SERVING);
health.setStatus('greeter.Greeter', ServingStatus.NOT_SERVING);
```

`statusOf(name)` gives the status, or null. `clearStatus(name)` removes it, and a `Check` for that name then gets `NOT_FOUND`.

## Services and isolates

Each [isolate](isolate.md) gets its own copy of your service. A database connection or a socket can not be copied, so make it on the first call:

```dart
class GreeterService extends GreeterServiceBase {
  HttpClient? _client;

  // made on the first call, in the isolate that runs the call
  HttpClient get client => _client ??= HttpClient();
}
```

## Deployment

Build your app with `dox build`. See [Deployment](deployment.md#build).

gRPC clients on the internet use TLS. There are two ways:

- Dox does the TLS. Set `tls` together with `http2: true` in `AppConfig`. Then `grpcurl` works without `-plaintext`. See [Deployment: HTTPS without a proxy](deployment.md#https-without-a-proxy).
- A proxy does the TLS and sends h2c to Dox. With nginx, use `grpc_pass`. With Caddy, use `h2c://` in `reverse_proxy`. See [Deployment: HTTP/2 and gRPC](deployment.md#http2-and-grpc).

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

With large messages and with streaming, grpc-go is faster on one core. `dox_grpc` is faster than `package:grpc` in all three tests.

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

For small calls, both servers stop at approximately 57,000 calls a second. This number is near the limit of the client on 4 cores.

### Test setup

- All servers run the same service: the gRPC interop `TestService`.
- The Dart servers are AOT builds. The build command is `dart build cli`.
- `package:grpc` runs on `dart:io` and has one isolate. For this reason, it is only in the one-core table.
- All tests ran in Linux containers on one machine with 8 cores. The server used 4 cores. The client, [ghz](https://ghz.sh), used the other 4 cores.
- The client used 16 connections. For small calls, it kept 128 calls open at the same time. For the other two tests, it kept 32 calls open.
- Each number is the median of 3 runs. Each run took 10 seconds, after a warm up of 3 seconds.

## Next steps

- [HTTP/2](http2.md): gRPC runs on HTTP/2.
- [Deployment](deployment.md): HTTPS with or without a proxy.
