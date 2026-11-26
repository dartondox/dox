---
date:
  created: 2026-11-26
authors:
  - dox
categories:
  - Releases
tags:
  - release
  - https
  - http2
slug: https-without-a-proxy
---

# HTTPS without a proxy in Dox

Dox can now serve HTTPS itself. Give it a certificate file and a key file, and a small server needs no proxy for TLS. HTTPS is off by default, so an app that does not turn it on works the same as before.

<!-- more -->

> **Key takeaways**
>
> - **Two lines of config.** Set `tls` in the app config with the certificate file and the key file.
> - **HTTP/2 for browsers and gRPC, with no proxy.** With `http2: true`, the client selects HTTP/2 or HTTP/1.1 in the TLS handshake.
> - **New certificate without a restart.** Call `reloadCertificate()` after certbot renews the certificate.
> - **No OpenSSL.** The TLS work is in Rust, with rustls.
> - **Fixes for bad request bodies.** A multipart body that is not valid now gets a `400`. Before, the request could wait with no answer.

## Turn on HTTPS

Set `tls` in the app config:

```dart title="lib/config/app.dart"
AppConfig appConfig = AppConfig(
  serverPort: 443,
  tls: TlsOptions(
    certificatePath: '/etc/letsencrypt/live/example.com/fullchain.pem',
    keyPath: '/etc/letsencrypt/live/example.com/privkey.pem',
  ),
  // ...
);
```

The two files are PEM files, for example `fullchain.pem` and `privkey.pem` of certbot. The server uses TLS 1.2 and TLS 1.3.

Your routes stay the same. WebSocket (`wss://`) and streamed responses work on the HTTPS port. If a file is bad, the app stops at the start with a clear error.

A new app from `dox create` has the `TLS_CERT` and `TLS_KEY` keys. Set them in `.env` to turn on HTTPS without a code change:

```bash title=".env"
TLS_CERT=/etc/letsencrypt/live/example.com/fullchain.pem
TLS_KEY=/etc/letsencrypt/live/example.com/privkey.pem
```

## Your app knows that it is on HTTPS

With `tls`, `req.scheme()` is `https` and `req.isSecure()` is true. Dox then does the correct thing for you:

- The session cookie and other cookies get `Secure`.
- `SecurityHeaders` sends HSTS.
- `req.fullUrl()` starts with `https://`.

## HTTP/2 and gRPC over TLS

Browsers use HTTP/2 only with TLS. Set `http2: true` together with `tls`:

```dart title="lib/config/app.dart"
AppConfig appConfig = AppConfig(
  http2: true,
  tls: TlsOptions(certificatePath: 'fullchain.pem', keyPath: 'privkey.pem'),
  // ...
);
```

Browsers and gRPC clients then use HTTP/2 with no proxy. Old clients continue to use HTTP/1.1 on the same port. `grpcurl` works without `-plaintext`.

## Use a new certificate without a restart

A certificate has an end date, and a tool such as certbot writes a new one before that date. Call `reloadCertificate()` to use the new certificate:

```dart
await Dox().server.reloadCertificate();
```

New connections get the new certificate, and open connections stay open. If a file is bad, the method throws a `TlsException` and the server keeps the old certificate.

Your app decides when to call the method. This example calls it when the process gets `SIGHUP`:

```dart title="bin/server.dart"
Future<void> main() async {
  // ...
  await Dox().startServer();
  ProcessSignal.sighup.watch().listen(reloadCertificate);
}

Future<void> reloadCertificate(ProcessSignal signal) async {
  try {
    await Dox().server.reloadCertificate();
    Logger.info('The server has the new certificate');
  } on TlsException catch (error) {
    Logger.danger('The server keeps the old certificate: $error');
  }
}
```

Then let certbot send the signal after each renewal:

```bash
certbot renew --deploy-hook "systemctl kill --signal=HUP dox"
```

## When to keep the proxy

Dox does the TLS, but it does not do everything a proxy does. Keep a proxy such as Caddy or nginx when you need one of these:

- Automatic certificates. Dox does not get or renew a certificate.
- A redirect from `http://` to `https://`.
- More than one app or domain on one server. One port has one certificate.
- Client certificates (mTLS).

For the full guide, read [HTTPS without a proxy](/latest/digging-deeper/deployment/#https-without-a-proxy).

## Fixes in this release

- **Multipart bodies that are not valid.** Some bad `multipart/form-data` bodies made the request wait with no answer, and the server then did not stop on shutdown. Others gave a `500`. Now they get a `400`.
- **Bracket keys with an unusual index.** A key such as `k[01]=z` or `k[+1]=z` lost its value in `req.body`, `req.query` and a DTO. Now only plain digits are a list index. Other keys are map keys and keep their value.
- **A warning for servers with more than 8 CPU cores.** The Dart VM runs 8 isolates at the same time by default, so a bigger server used only approximately 8 cores. Dox now shows a warning at the start, with the setting that lets all isolates run. See [Deployment](/latest/digging-deeper/deployment/).

Fuzz tests found the first two bugs.

## Versions

| Package | New version |
| --- | --- |
| `dox_http_native` | 3.2.6 |
| `dox_core` | 3.2.6 |
| App template | v3.2.6 |

To update an app, run `dart pub upgrade`. HTTPS stays off until you turn it on.
