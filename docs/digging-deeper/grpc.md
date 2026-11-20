---
icon: lucide/network
---

# gRPC

The `dox_grpc` package serves gRPC from your Dox app. It is real gRPC over HTTP/2 without TLS (h2c), so it works with any gRPC client, in any language.

You write a `.proto` file and make the Dart code with `protoc`. You then extend the generated service class. Dox serves it on the same port as your HTTP routes, and your normal middleware runs before each call.

## Install

Add the package:

```bash
dart pub add dox_grpc
```

Your generated code also imports `protobuf` and `grpc`, so add them too:

```bash
dart pub add protobuf grpc
```

You must build with `dox build` or `dart build cli`, because gRPC runs on the [native server](native-server.md). See [Deployment](deployment.md).

## Turn on HTTP/2

gRPC only runs over HTTP/2, and HTTP/2 is off by default. Turn it on in `lib/config/app.dart`:

```dart title="lib/config/app.dart"
AppConfig appConfig = AppConfig(
  http2: true,
  // ...
);
```

The same port then speaks HTTP/1.1 and HTTP/2. Your normal routes do not change. See [Native server: HTTP/2](native-server.md#http2) for the details.

A gRPC call to a server that has no `http2: true` gets HTTP status `505`.

## Write a .proto file

Put your `.proto` files in `protos/`:

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

## Make the Dart code

Install `protoc` first (for example `brew install protobuf`). Then install the Dart plugin for it once, and make sure `~/.pub-cache/bin` is on your `PATH`:

```bash
dart pub global activate protoc_plugin
```

Then make the code:

```bash
protoc --dart_out=grpc:lib/generated -Iprotos protos/greeter.proto
```

It writes the messages and a `GreeterServiceBase` class. Run it again each time you change the `.proto` file.

## Write the service

Extend the generated base class. Each `rpc` is one method:

```dart title="lib/app/grpc/greeter_service.dart"
import 'package:dox_grpc/dox_grpc.dart';

import '../../generated/greeter.pbgrpc.dart';

class GreeterService extends GreeterServiceBase {
  @override
  Future<HelloReply> sayHello(ServiceCall call, HelloRequest request) async {
    return HelloReply(message: 'Hello ${request.name}');
  }

  // the other three methods are in "The call types"
}
```

## Register it

Register the service in a router with no prefix:

```dart title="lib/routes/grpc_router.dart"
import 'package:dox_core/dox_core.dart';
import 'package:dox_grpc/dox_grpc.dart';

import '../app/grpc/greeter_service.dart'; // your GreeterService
import '../app/http/middleware/auth_middleware.dart'; // your AuthMiddleware

class GrpcRouter extends Router {
  @override
  List<dynamic> get middleware => <dynamic>[AuthMiddleware()];

  @override
  void register() {
    Grpc.register(GreeterService());
  }
}
```

`Grpc.register` adds the route `POST /<package.Service>/{method}`. A gRPC client calls that exact path, for example `/helloworld.Greeter/SayHello`. Any prefix would change the path, and no client could reach it.

So do not put it in the `api` router, and not inside a `Route.group` or a `Route.prefix`. Dox throws a `StateError` at start if the path changed.

A call to a service you did not register, or to a method the service does not have, gets `UNIMPLEMENTED`.

The gRPC routes skip `RequestTimeout`, so a long stream is not cut.

A load balancer has no token. Register the [health service](#health-check) in its own router, without the auth middleware:

```dart title="lib/routes/grpc_health_router.dart"
class GrpcHealthRouter extends Router {
  @override
  void register() {
    // the first Grpc.register in the app
    Grpc.register(HealthService());
  }
}
```

## The call types

### Unary

One request, one reply. The method returns a `Future`:

```dart
@override
Future<HelloReply> sayHello(ServiceCall call, HelloRequest request) async {
  return HelloReply(message: 'Hello ${request.name}');
}
```

### Server streaming

One request, many replies. The method returns a `Stream`:

```dart
@override
Stream<HelloReply> sayHelloMany(ServiceCall call, HelloRequest request) async* {
  for (int i = 1; i <= 3; i++) {
    if (call.isCanceled) return;
    yield HelloReply(message: 'Hello ${request.name} $i');
  }
}
```

A long stream should stop when `call.isCanceled` is true. See [Deadlines and cancel](#deadlines-and-cancel).

### Client streaming

Many requests, one reply. The method gets a `Stream` of requests:

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
Stream<HelloReply> chat(ServiceCall call, Stream<HelloRequest> request) async* {
  await for (HelloRequest item in request) {
    yield HelloReply(message: 'Hello ${item.name}');
  }
}
```

## Errors

Throw a `GrpcException` to end the call with a status. `GrpcStatus` is an enum of the gRPC status codes:

```dart
throw GrpcException(GrpcStatus.notFound, 'No user 5');
```

The message goes to the client in `grpc-message`. You can pass protobuf messages as a third argument. They go in `grpc-status-details-bin`.

A `GrpcError` from `package:grpc` works the same way.

Any other error ends the call with `INTERNAL`. Dox sends it to your `ExceptionHandler`, like other errors. The client sees the text of the error only when `APP_ENV` is `development` or `local`.

## Metadata

Metadata is the gRPC word for headers.

- `call.clientMetadata` has the headers of the request, except the `grpc-*` ones.
- Set `call.headers` before you send the first message.
- Set `call.trailers` before the call ends.

```dart
@override
Future<HelloReply> sayHello(ServiceCall call, HelloRequest request) async {
  String? language = call.clientMetadata['accept-language'];
  call.headers!['x-served-by'] = 'greeter';
  return HelloReply(message: 'Hello ${request.name} ($language)');
}
```

A value whose name ends in `-bin` stays base64 text. `GrpcWire.decodeBinary` gives you its bytes. `GrpcWire.encodeBinary` makes one.

## Deadlines and cancel

A client can set a deadline. When it passes, the call ends with `DEADLINE_EXCEEDED` and `call.isTimedOut` is true. `call.deadline` tells you when it is.

When the client cancels or leaves, `call.isCanceled` is true and the request stream ends. A long server stream should check it, and stop work when it is true.

## Middleware

Most services need to know who calls them. The middleware of the router runs before each call, so this is where you add auth. A client sends its token as metadata, and the middleware reads it the same way as an HTTP header:

```dart
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

When a middleware throws a Dox error, the client gets a gRPC status with the message. The message of a 5xx error is hidden unless `APP_ENV` is `development` or `local`. The map is:

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

You can also wrap a service in `Route.middleware([...], () => Grpc.register(...))`. But the first `Grpc.register` in your app must stay outside it. See [Health check](#health-check).

## Options

The defaults fit most services. Pass `GrpcOptions` to change the limits of one service:

```dart
Grpc.register(
  GreeterService(),
  options: GrpcOptions(
    maxReceiveMessageSize: 4 * 1024 * 1024,
    maxSendMessageSize: 4 * 1024 * 1024,
    gzipResponses: false,
    idleTimeout: Duration(minutes: 5),
  ),
);
```

### Message size

`maxReceiveMessageSize` and `maxSendMessageSize` are the biggest message in bytes. The default for both is 4 MiB. A bigger message ends the call with `RESOURCE_EXHAUSTED`. The receive limit also counts the bytes after unzip.

### gzip

Dox always reads gzip requests. It zips the responses only when you set `gzipResponses: true`, and only for clients that accept gzip. It is off by default, because it costs CPU for each message and most gRPC messages are small.

### idleTimeout

It is off by default. When you set it, a call with no message in or out for that long ends with `DEADLINE_EXCEEDED`. It frees the call of a client that never reads the answer.

The quiet time of your own method counts too, so set it longer than your slowest quiet method. `Duration(minutes: 5)` is a good start. The deadline of the client always works, with or without `idleTimeout`.

## Health check

`HealthService` is the standard `grpc.health.v1.Health` service, with `Check` and `Watch`. Load balancers and Kubernetes can call it:

```dart
class GrpcHealthRouter extends Router {
  @override
  void register() {
    // this is the first Grpc.register in the app
    HealthService health = HealthService();
    Grpc.register(health);
    health.setStatus('helloworld.Greeter', ServingStatus.SERVING);
  }
}
```

The empty name `''` is the whole server. It starts as `SERVING`. A change you make in one isolate goes to the other isolates too.

Register the health service first, in a router with no prefix and no `Route.middleware`. The first `Grpc.register` also adds the `UNIMPLEMENTED` answer for unknown services, and that answer must not run your middleware. Dox throws a `StateError` at start if the first one is inside `Route.middleware`.

## Services and isolates

Dox runs your app in many [isolates](isolate.md), and each one gets its own copy of your service. So a service must not hold a database connection, a socket or a `ReceivePort` in a field that is set when you register it. Those can not be copied to another isolate.

Make them on the first call, inside the isolate that runs the call:

```dart
class GreeterService extends GreeterServiceBase {
  Database? _db;

  // made on the first call, in the isolate that runs it
  Database get db => _db ??= Database.connect();

  @override
  Future<HelloReply> sayHello(ServiceCall call, HelloRequest request) async {
    User user = await db.findUser(request.name);
    return HelloReply(message: 'Hello ${user.name}');
  }
}
```

## Deployment

Put TLS on a proxy in front of the app. The proxy talks h2c to Dox. nginx uses `grpc_pass` for the gRPC paths, and Caddy uses `h2c://`. See [Deployment: HTTP/2 and gRPC](deployment.md#http2-and-grpc) for the config.
