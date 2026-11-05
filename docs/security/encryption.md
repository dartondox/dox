---
icon: lucide/lock-keyhole
---

# Encryption

This page shows how to encrypt and decrypt text with `AESEncryptor`.

Dox uses `AESEncryptor` to encrypt cookies with your `APP_KEY`.
You can also call it yourself.

## Encrypt and decrypt

```dart
import 'package:dox_core/dox_core.dart';

String secret = env.appKey;

String encoded = AESEncryptor.encode('Hello world', secret);
String decoded = AESEncryptor.decode(encoded, secret); // 'Hello world'
```

- `encode` returns base64 text.
- The same text gives a different output each time.
- `decode` throws `DecryptException` when the text was changed, or the key is wrong. It is a `400 Bad Request` error.
- The AES key is not the secret itself. Dox makes a 32-byte key (AES-256) from the secret with HKDF-SHA256 (RFC 5869) and a label. The default label is `dox:encrypt`. Pick another one with `purpose:`, like `AESEncryptor.encode(text, secret, purpose: 'app:invoice')`. `decode` needs the same `purpose`.

Make a new 32-character `APP_KEY` with the CLI:

```bash
dox key:generate
```

It writes a random key of letters and digits to `APP_KEY` in `.env`.

## One key per purpose

Dox does not use `APP_KEY` as it is. It makes one key per purpose from it, with HKDF-SHA256 and a label:

| Label | Used for |
| --- | --- |
| `dox:cookie` | encrypted cookies, and the `cookie` session driver |
| `dox:jwt` | the HMAC key of `JwtAuthDriver` (with a `SecretKey`) |
| `dox:encrypt` | `AESEncryptor` when you give no `purpose` |
| `dox:signed-url` | for signed URLs |

So a value made for one purpose can not be used for another one.
`KeyDerivation.forAppKey(label)` gives the 32-byte key of a label. Each isolate makes it once.

At startup Dox checks `APP_KEY`. When it is empty, not exactly 32 bytes, or an old public sample key, the app stops.
In `development`, `local`, `test` and `testing` it only prints a warning.

- Keep `APP_KEY` in `.env` or in the secrets of your host. Never put it in code or in git.
- If you change `APP_KEY` with no `previousKeys`, old encrypted cookies and sessions can not be read any more, so every user is logged out. JWT tokens signed with it stop working too. See [Change the key](#change-the-key-key-rotation).

## Change the key (key rotation)

Change `APP_KEY` from time to time, or when someone who knew it leaves the team.
With `previousKeys`, users stay logged in while you change it.

### Steps

1. Copy the current `APP_KEY` to `APP_PREVIOUS_KEYS`.
2. Run `dox key:generate`. It writes a new `APP_KEY`. Now `.env` has both:

    ```bash title=".env"
    APP_KEY=the-new-32-character-app-key....
    APP_PREVIOUS_KEYS=the-old-32-character-app-key....
    ```

3. Read it in the env class, and give it to `AppConfig`:

    ```dart title="lib/config/env.dart"
    List<String> get appPreviousKeys => <String>[]; // APP_PREVIOUS_KEYS=a,b
    ```

    ```dart title="lib/config/app.dart"
    AppConfig(
      appKey: env.appKey,
      previousKeys: env.appPreviousKeys,
    )
    ```

4. Deploy. Every instance must get the new env at the same time.
5. Wait until the old cookies have expired: the session `lifetime`, and the `maxAge` of your own cookies.
6. Remove the old key from `APP_PREVIOUS_KEYS` and deploy again.

`APP_PREVIOUS_KEYS` can hold more than one key, comma separated. Dox tries them in order.

### What reads the old keys

| Value | With an old key |
| --- | --- |
| encrypted cookies (`req.cookie`) | read |
| `cookie` session driver | read |
| CSRF token | read (it is in the session) |
| JWT tokens of `JwtAuthDriver(secret: SecretKey(env.appKey))` | checked. A JWT secret that is not `APP_KEY` needs its own `previousSecrets` option, see [Authentication](authentication.md#change-the-jwt-secret). |
| `AESEncryptor.decode` in your code | read only when you pass `previousSecrets: Dox().config.previousKeys` |
| anything new | made with `APP_KEY` only |

Dox writes a cookie with the new key the next time it sends that cookie.
So a user who comes back during step 5 moves to the new key without noticing.

### When the key leaked

Do **not** put a leaked key in `previousKeys`.
Anyone who has it can still make cookies and JWT tokens that Dox accepts.
Change `APP_KEY` with no `previousKeys`. Every user is logged out, and that is what you want.

## Cookies

`DoxCookie` encrypts its value with `APP_KEY` by default.
`req.cookie(key)` decrypts it.
To decrypt a raw cookie value yourself, call `DoxCookie.decrypt(name, value)`. It returns `null` when the value was changed, was made with another key, or was made for another cookie name.

```dart
return response().cookie(DoxCookie('theme', 'dark'));  // encrypted
DoxCookie('theme', 'dark', encrypt: false);             // plain text

String? theme = req.cookie('theme');                    // decrypted
String? raw = req.cookie('theme', decrypt: false);      // as sent
```

`req.cookie(key)` returns `null` when the cookie was changed, was made with another `APP_KEY`, or was made for another cookie name.
The cookie name is bound to the encrypted value, so a value can not be copied from one cookie to another.

## How it works

`AESEncryptor` uses AES-256-GCM. The work runs in Rust (in `dox_http_native`), with the AES instructions of the CPU. One cookie takes about 1–2 µs.

- Each message gets a new random 12-byte nonce.
- The output is base64 of `nonce + encrypted text + tag`.
- The 16-byte tag checks the message. If someone changes one byte, `decode` throws.
- `encode` and `decode` also take `associatedData`, a text like a cookie name. It is not in the output, but `decode` needs the same value. Cookies use the cookie name here.

To store passwords, do not encrypt them. Hash them. See [Hashing](hashing.md).
