---
date:
  created: 2026-11-25
authors:
  - dox
categories:
  - Releases
tags:
  - release
  - security
slug: dox-patch-release-2026-11-25
---

# Security fixes release: 25 November 2026

This release has a security fix for the native HTTP server and for the native HTTP client. We recommend that you update. The server also has 10 more fixes, which the HTTP server tests of the Dart SDK found.

<!-- more -->

> **Key takeaways**
>
> - **Security fix: request smuggling.** The server accepted a lone line feed in parts of a chunked request body. A proxy in front of the server could read the same bytes as two requests.
> - **The same fix in the client.** `dox_http_client` now refuses such bytes in a chunked answer.
> - **The Dart SDK server tests now run against the server.** They found 10 differences from `dart:io`, and each one is fixed.
> - **Easy to update.** Patch versions only. Run `dart pub upgrade dox_http_native dox_http_client`.

## Versions

| Package | New version |
| --- | --- |
| `dox_http_native` | 3.2.5 |
| `dox_http_client` | 0.0.5 |

No change: all the other packages, the `dox` CLI and the app template.

## How to update

1. Get the new versions of the 2 packages:

    ```bash
    dart pub upgrade dox_http_native dox_http_client
    ```

    This changes only these 2 packages. It also works when your app gets them through other Dox packages.

2. Build or start the app again. The new native libraries download automatically.

There is no API change and no config change.

## Security fix: request smuggling

A request body with `Transfer-Encoding: chunked` comes in parts. Each part starts with a size line, and the body can end with trailer lines. Each line must end with `\r\n`.

The server accepted a lone `\n` in two places:

- In a chunk extension, the text after `;` in a size line. For example: `5;a\nb\r\n`.
- In a trailer line after the last part.

Some proxies end a line at a lone `\n`. Such a proxy and the server then see a different end of the body. An attacker can use this to hide a second request in the body of the first one. The proxy does not see this second request, so its rules do not apply to it. This attack is request smuggling. It is the same type as CVE-2025-55315 in ASP.NET Core and CVE-2026-19203 in Jetty.

Now the server answers `400` to a size line or a trailer that has a control byte, for example a lone `\n`, a lone `\r` or a NUL byte. A tab is permitted. A correct client never sends these bytes, so a normal request does not change.

**Who is at risk:** an app behind a proxy or a load balancer that reads chunked bodies with a lone `\n` as a line end. An app with no proxy in front of it is not at risk from this issue.

### The client

`dox_http_client` had the same issue when it read a chunked answer. Now each size line and each trailer line of an answer must end with `\r\n`, and an answer with a control byte in these lines fails with `badResponse`. Before, a server or a proxy could make the client read the rest of a body as the next answer on the same connection.

We found these issues in the security check that we do before each release of the HTTP packages. The fuzz tests now check the new rule too.

## Fixes from the Dart SDK tests

The Dart SDK has tests for its own HTTP server in `dart:io`. These tests now run against the native server in CI: 755 pass. The tests that do not apply to the native server are skipped. They found these differences, and each one is fixed:

- A client that sent more than 64 pipelined requests, and then closed its send side, got answers for only the first 64.
- A client that closed its connection in the middle of a request body kept the connection open until `bodyTimeout`.
- `requestedUri` was wrong for a request line with an absolute URI, like `GET http://example.com/ HTTP/1.1`.
- A size line that was empty, or that started with `;`, was read as the last part of a chunked body. Now the request gets `400`. This was also a request smuggling risk.
- A handler that set a `Date` header made an answer with two `Date` headers.
- `response.headers.clear()` did not reset `chunkedTransferEncoding`.
- `response.add` with a value outside 0 to 255, like `[256]`, sent other bytes. Now it throws an `ArgumentError`, as in `dart:io`.
- The answer to a `HEAD` request had `content-length: 0`, not the length that the handler set.
- `NativeWebSocket.upgrade(protocol:)` sent a protocol that the client did not offer. Now the request gets `500`, as in `dart:io`.
- When the stream of `addStream` failed before the head went out, the request got no answer. Now it gets `500`.

Full list: the CHANGELOG of [`dox_http_native`](https://pub.dev/packages/dox_http_native/changelog) and of [`dox_http_client`](https://pub.dev/packages/dox_http_client/changelog).
