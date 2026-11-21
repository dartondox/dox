---
date:
  created: 2026-11-21
authors:
  - dox
categories:
  - Releases
tags:
  - release
  - http2
  - grpc
slug: http2-and-grpc
---

# HTTP/2 and gRPC in Dox

Dox now serves HTTP/2 and gRPC on the same port as your HTTP routes. HTTP/2 is off by default, so an app that does not turn it on works the same as before.

<!-- more -->

> **Key takeaways**
>
> - **HTTP/2 on the same port.** Set `http2: true`. The port then accepts HTTP/1.1 and HTTP/2. Your routes, middleware and controllers do not change.
> - **gRPC with the new `dox_grpc` package.** Run `dox add grpc`, write a `.proto` file, and register your service with one line.
> - **Your middleware runs before each gRPC call.** Your HTTP routes and your gRPC services can use the same auth.
> - **Fast.** On one core, `dox_grpc` does 48,700 small calls a second. grpc-go does 44,000 and `package:grpc` does 35,300.
> - **Safe by default.** Flood limits stop the known HTTP/2 attacks, for example Rapid Reset.

## Turn on HTTP/2

Set `http2` to `true` in the app config:

```dart title="lib/config/app.dart"
AppConfig appConfig = AppConfig(
  http2: true,
  // ...
);
```

Dox finds the protocol of each connection. Old clients and health checks continue to use HTTP/1.1 on the same port.

A new app from `dox create` has an `APP_HTTP2` key. Set `APP_HTTP2=true` in `.env` to turn on HTTP/2 without a code change.

Dox uses h2c: HTTP/2 over plain TCP. Your proxy (for example Caddy or nginx) does the TLS, and then sends the requests to Dox:

```text
browser  --HTTP/2 + TLS-->  proxy  --h2c or HTTP/1.1-->  Dox
```

For more, read [HTTP/2](/latest/digging-deeper/http2/).

## Serve gRPC

gRPC lets your services call each other with typed messages. You write the calls one time in a `.proto` file, and each side gets typed code from it.

Run the setup command in your app:

```bash
dox add grpc
```

The command adds the packages, a sample `protos/greeter.proto` and a gRPC router with the health service. It does not overwrite a file.

Extend the class that `protoc` makes. Each `rpc` in the `.proto` file is one method:

```dart title="lib/app/grpc/greeter_service.dart"
class GreeterService extends GreeterServiceBase {
  @override
  Future<HelloReply> sayHello(ServiceCall call, HelloRequest request) async {
    return HelloReply(message: 'Hello ${request.name}');
  }
}
```

Register the service in a router that has no prefix:

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

The middleware of the router runs before each call. A client sends its token as metadata, and the middleware reads it the same as an HTTP header. When the middleware throws `401`, the client gets `UNAUTHENTICATED`.

`dox_grpc` supports:

- The four call types: unary, server streaming, client streaming and bidirectional streaming.
- Deadlines, cancel and metadata.
- `GrpcStatus` errors with status details.
- gzip and message size limits (4 MiB by default).
- The standard health service.

For more, read [gRPC](/latest/digging-deeper/grpc/).

## Tested with real gRPC tools

A gRPC server must work with clients in other languages. CI runs the grpc-go interop test suite against `dox_grpc` three times: direct, behind nginx and behind Caddy. CI also does a test with `grpcurl`. The HTTP/2 server must pass the strict h2spec conformance suite.

## Speed

Calls a second on one core:

| Test | `dox_grpc` | `package:grpc` | grpc-go |
| --- | ---: | ---: | ---: |
| Unary, small message | **48,700** | 35,300 | 44,000 |
| Unary, 100 KB reply | 14,600 | 11,400 | **17,200** |
| Server streaming, 100 messages of 1 KB | 4,390 | 2,010 | **6,240** |

Dox does the most small calls, and small calls are the most usual type of gRPC call. With large messages and with streaming, grpc-go is faster on one core. `dox_grpc` is faster than `package:grpc` in all three tests.

On four cores, Dox and grpc-go are almost equal. For the full numbers and the test setup, read [the gRPC benchmark](/latest/digging-deeper/grpc/#benchmark).

## Safe by default

HTTP/2 has its own attacks. A client can open and reset streams very fast, or send many small frames. Dox has limits for these attacks:

- Too many stream resets (Rapid Reset, CVE-2023-44487 and CVE-2025-8671). The connection first drains: open requests get their answers, and a proxy sends new requests on a new connection. If the resets continue, the connection closes.
- Too many SETTINGS, PING or empty frames close the connection.
- A connection has a maximum of 250 open requests (`maxConcurrentStreams`).
- Data that waits for a slow reader has a limit for each connection.
- A gRPC call with no message for 5 minutes ends with `DEADLINE_EXCEEDED`. Set `idleTimeout` to change this.

You do not set anything for these limits. The defaults are correct for most apps.

## Versions

| Package | New version |
| --- | --- |
| `dox_grpc` | 0.0.1 (new) |
| `dox_http_native` | 3.2.2 |
| `dox_core` | 3.2.4 |
| App template | v3.2.4 |

`dox_grpc` has its own version line, because it is a new package.

To update an app, run `dart pub upgrade`. HTTP/2 stays off until you turn it on.
