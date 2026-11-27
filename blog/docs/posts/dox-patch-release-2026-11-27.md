---
date:
  created: 2026-11-27
authors:
  - dox
categories:
  - Releases
tags:
  - release
slug: dox-patch-release-2026-11-27
---

# Dox patch release: 27 November 2026

This release is patch versions only. Dox can now serve HTTPS with no proxy, and each server isolate can have its own memory. The two features are off by default. The release also has fixes for request bodies that are not valid.

<!-- more -->

> **Key takeaways**
>
> - **HTTPS without a proxy.** Set `tls` in the app config with a certificate file and a key file. Read [HTTPS without a proxy in Dox](https-without-a-proxy.md).
> - **Isolate groups.** One flag gives each isolate its own heap and its own garbage collector. Read [Isolate groups](isolate-groups.md).
> - **Fixes for bad request bodies.** A multipart body that is not valid now gets a `400`. Before, the request could wait with no answer.
> - **Easy to update.** Patch versions only. Run `dart pub upgrade`, then check [Read before you update](#read-before-you-update).

## Versions

| Package | New version |
| --- | --- |
| `dox_http_native` | 3.2.6 |
| `dox_core` | 3.2.6 |
| `dox_orm` | 3.2.4 |
| `dox_migration` | 3.2.4 |
| `dox_cache_database` | 3.2.4 |
| App template | v3.2.6 |

`dox_orm` and `dox_cache_database` have no changes. Their version goes up with `dox_migration`.

No change: all the other packages and the `dox` CLI.

## How to update

1. Get the new versions:

    ```bash
    dart pub upgrade
    ```

2. Build or start the app again. The new native library downloads automatically.

3. Read [Read before you update](#read-before-you-update).

There is no API change. An app that does not turn on the new features works the same as before.

## New

### HTTPS without a proxy

Dox can do the TLS work itself. Set `tls` in the app config:

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

- The server uses TLS 1.2 and TLS 1.3. The TLS work is in Rust, with rustls. There is no OpenSSL.
- With `http2: true`, browsers and gRPC clients use HTTP/2 with no proxy.
- `Dox().server.reloadCertificate()` uses a new certificate without a restart.
- `req.scheme()` is `https`. Cookies get `Secure`, and `SecurityHeaders` sends HSTS.
- `DoxTestClient` speaks HTTPS when the config has `tls`.
- A new app from template v3.2.6 has the `TLS_CERT` and `TLS_KEY` keys. Set them in `.env` to turn on HTTPS without a code change.

Dox does not get or renew a certificate, and it does not redirect `http://` to `https://`. For these, keep a proxy. See [HTTPS without a proxy](/latest/digging-deeper/deployment/#https-without-a-proxy).

### Isolate groups

By default, all server isolates share one heap and one garbage collector, and the Dart VM runs only 8 of them at the same time. Turn on `isolateGroups` to give each isolate its own heap:

```dart title="lib/config/app.dart"
AppConfig appConfig = AppConfig(
  flags: CoreFlags(isolateGroups: env.appEnv == 'production'),
  // ...
);
```

- A garbage collection in one isolate does not stop the others.
- The limit of 8 isolates does not apply.
- Each isolate runs `main()` again. `Dox().isPrimary` is true only in the first isolate. Use it for work that must run one time.
- With `dox_migration` 3.2.4, the migrations in `main()` run only in the first isolate.

See [Give each isolate its own memory](/latest/digging-deeper/deployment/#give-each-isolate-its-own-memory).

### A warning for servers with more than 8 CPU cores

The Dart VM runs 8 isolates at the same time by default, so a bigger server used only approximately 8 cores. Dox now shows a warning at the start when the app has more isolates than the VM runs. The warning gives the `DART_VM_OPTIONS` value that lets all isolates run.

## Fixes

- **Multipart bodies that are not valid.** Some bad `multipart/form-data` bodies made the request wait with no answer, and the server then did not stop on shutdown. Others gave a `500`. Now they get a `400`.
- **Bracket keys with an unusual index.** A key such as `k[01]=z` or `k[+1]=z` lost its value in `req.body`, `req.query` and a DTO. Now only plain digits are a list index. Other keys are map keys and keep their value: `k[01]=z` gives `{k: {01: z}}`.

Fuzz tests found these bugs.

## Read before you update

- **`dox_core` 3.2.6 needs `dox_http_native` 3.2.6.** `dart pub upgrade` gets the two together.
- **The native library is bigger.** The library of `dox_http_native` goes from approximately 0.6 MB to approximately 1.4 MB, because it now has the TLS code.
- **A bracket key that is not plain digits is now a map key.** `k[01]=z` gave a list before, with a lost value. Now it gives a map. A key like `k[+5000]` got a `422` before. Now it is a map key too.
- **With isolate groups, `main()` runs in each isolate.** Read your settings and the app key from the env, not from command line arguments.

Full list: the CHANGELOG of each package.
