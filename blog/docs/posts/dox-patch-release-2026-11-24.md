---
date:
  created: 2026-11-24
authors:
  - dox
categories:
  - Releases
tags:
  - release
slug: dox-patch-release-2026-11-24
---

# Dox patch release: 24 November 2026

This release is patch versions only. Dox has a new native HTTP client, and five packages now send their requests through it. The Linux libraries of the native packages no longer need `libgcc_s`, so the Docker image of an app is simpler.

<!-- more -->

> **Key takeaways**
>
> - **New package: `dox_http_client`.** A native HTTP client for Dart, with HTTP/1.1 and HTTP/2. It works in any Dart app.
> - **Faster requests to other servers.** Mail, S3 storage, Inertia SSR, scheduler pings and the MCP OAuth fetcher use the new client.
> - **Simpler Docker image.** The `Dockerfile` of an app does not copy `libgcc_s.so.1` any more.
> - **Easy to update.** Patch versions only. Run `dart pub upgrade`, then check [Read before you update](#read-before-you-update).

## Versions

| Package | New version |
| --- | --- |
| `dox_http_client` | 0.0.4 (new) |
| `dox_mailer` | 3.2.3 |
| `dox_storage` | 3.2.3 |
| `dox_inertia` | 3.2.4 |
| `dox_scheduler` | 3.2.3 |
| `dox_mcp` | 3.2.3 |
| `dox_http_native` | 3.2.4 |
| `dox_postgres_native` | 3.2.2 |
| `dox_mysql_native` | 3.2.2 |
| `dox_pdf_lib` | 0.0.4 |
| App template | v3.2.5 |

No change: all the other packages and the `dox` CLI.

## How to update

1. Get the new versions:

    ```bash
    dart pub upgrade
    ```

2. Build or start the app again. The new native libraries download automatically.

3. Read [Read before you update](#read-before-you-update).

There is no API change and no config change.

## New

### dox_http_client

[`dox_http_client`](https://pub.dev/packages/dox_http_client) is a native HTTP client. Use it when your app calls another server, for example an API in a handler.

```dart
import 'package:dox_http_client/dox_http_client.dart';

final DoxHttpClient client = DoxHttpClient();

Future<String> rates() async {
  DoxHttpClientResponse res = await client.get(
    Uri.parse('https://api.example.com/rates'),
  );
  return res.body;
}
```

- Rust owns the sockets and reads the answers. The socket work runs on the thread of your isolate, which makes the client faster than `HttpClient` of `dart:io`.
- On `https://`, the client uses HTTP/2 when the server has it. The requests to one server then share one connection.
- The client keeps its connections open and uses them again.
- It follows redirects, decodes gzip and brotli bodies, and streams big bodies with a small memory use.
- `DoxHttpPackageClient` is a `Client` of [package:http](https://pub.dev/packages/http). Give it to a package that takes an `http.Client`. It passes all the tests of the Dart team for `package:http` clients.

The package does not depend on Dox. The version line starts at 0.0.x, so the API can still change.

## Faster

Five packages now send their requests through `dox_http_client`:

| Package | What uses the native client |
| --- | --- |
| `dox_mailer` | The HTTP transports: Resend, SES, Mailgun, Postmark and Azure |
| `dox_storage` | The S3 driver |
| `dox_inertia` | The request to the SSR server |
| `dox_scheduler` | The pings, like `pingBefore` and `thenPing` |
| `dox_mcp` | `McpOAuthHttpFetcher`, which loads client metadata documents |

Mail and S3 requests use HTTP/2 when the server has it. Your code does not change. A client that you pass, like `client` in a mail transport or `httpClient` in the S3 driver, is used as before. A custom `sendPing` of the scheduler is used as before too.

## Simpler Docker image

Before this release, the Linux libraries of the native packages needed `libgcc_s.so.1`. A `FROM scratch` image does not have this file, so the `Dockerfile` of an app copied it. Without the copy, the app did not start.

Now the ready-built Linux libraries need only glibc 2.34 or newer, as before. This applies to `dox_http_native`, `dox_postgres_native`, `dox_mysql_native`, `dox_pdf_lib` and `dox_http_client`.

A new app from template v3.2.5 has a `Dockerfile` without the copy. In an app that you already have, you can remove these lines after the update:

```dockerfile
  # the native HTTP server (Rust) needs libgcc_s, which /runtime/ does not have
  && LIBGCC=$(find / -name libgcc_s.so.1 -path '*lib*' | head -n 1) \
  && mkdir -p /out$(dirname $LIBGCC) && cp $LIBGCC /out$LIBGCC
```

Remove the ` \` at the end of the line before them too. The lines do no harm if you keep them. See the [Docker guide](/latest/guides/docker/) for the full file.

## Read before you update

- **`connectTimeout` of `McpOAuthHttpFetcher` has a new meaning.** It is now the limit for the lookup of the host only. `timeout` is the limit for the connection and for the answer. The guards against SSRF do not change.
- **Remove the `libgcc_s` lines only after the update.** With `dox_http_native` older than 3.2.4, an image without `libgcc_s.so.1` stops at start with `dox_http_native did not load`.
- **New release tags of `dox_http_native`.** The tag is now `dox_http_native-v<version>`, because the repository holds 2 packages. The build hook finds the library automatically. This is important only if you download the library with your own script.

Full list: the CHANGELOG of each package.
