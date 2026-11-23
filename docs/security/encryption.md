---
icon: lucide/lock-keyhole
---

# Encryption

`Crypt` and `AESEncryptor` encrypt and decrypt text with AES-256-GCM, so you can store or send data that nobody else can read or change.

Dox uses the same encryption for cookies and the `cookie` session driver, with your `APP_KEY`.

## Setup

The key is the `APP_KEY` in `.env`. Make a new one with the CLI. It writes a random key of 32 letters and digits:

```bash
dox key:generate
```

Keep `APP_KEY` in `.env` or in the secrets of your host. Never put it in code or in git.

At startup Dox checks `APP_KEY`. When it is empty, not exactly 32 bytes, or a public sample key, the app stops. In `development`, `local`, `test` and `testing` it only prints a warning.

## Encrypting values

`Crypt` uses the `APP_KEY` of the app, so you do not pass a key. Use `encryptString` for text:

```dart
String secret = Crypt.encryptString('card-1234');
```

Use `encrypt` for any JSON value:

```dart
String data = Crypt.encrypt(<String, dynamic>{'id': 5}); // any JSON value
```

The result is base64 text. The same value gives a different result each time.

## Decrypting values

Use `decryptString` or `decrypt` to get the value back:

```dart
String card = Crypt.decryptString(secret); // 'card-1234'

Map<String, dynamic> map = Crypt.decrypt(data);
```

They throw a `DecryptException` when the text was changed or made with another key. The client then gets a `400`. They also try the old keys in `AppConfig.previousKeys`, so values still work after you [rotate the key](#change-the-key-key-rotation).

## Using your own key

Sometimes you want a key that is not the `APP_KEY`. Use `AESEncryptor` and pass the key yourself:

```dart
import 'package:dox_core/dox_core.dart';

String secret = env.appKey;

String encoded = AESEncryptor.encode('Hello world', secret);
String decoded = AESEncryptor.decode(encoded, secret); // 'Hello world'
```

`decode` throws a `DecryptException` when the text was changed or the key is wrong.

### One key per purpose

Dox does not use your key as it is. It makes a 32-byte key from it with HKDF-SHA256 and a label. The default label is `dox:encrypt`. You should pick your own label with `purpose:`, so a value made for one purpose can not be used for another. `decode` needs the same `purpose`:

```dart
AESEncryptor.encode(text, secret, purpose: 'app:invoice')
```

Dox uses these labels for its own keys:

| Label | Used for |
| --- | --- |
| `dox:cookie` | encrypted cookies, and the `cookie` session driver |
| `dox:jwt` | the HMAC key of `JwtAuthDriver` (with a `SecretKey`) |
| `dox:encrypt` | `AESEncryptor` when you give no `purpose` |
| `dox:signed-url` | for signed URLs |

## Encrypted cookies

`DoxCookie` encrypts its value with `APP_KEY` by default, and `req.cookie(key)` decrypts it:

```dart
return response().cookie(DoxCookie('theme', 'dark'));  // encrypted

String? theme = req.cookie('theme');                    // decrypted
```

If you need a plain text cookie, turn encryption off. Read the raw value with `decrypt: false`:

```dart
DoxCookie('theme', 'dark', encrypt: false);             // plain text

String? raw = req.cookie('theme', decrypt: false);      // as sent
```

`req.cookie(key)` returns `null` when the cookie was changed, made with another `APP_KEY`, or made for another cookie name. The cookie name is bound to the value, so a value can not be copied from one cookie to another. To decrypt a raw cookie value yourself, use `DoxCookie.decrypt(name, value)`.

## Rotating the key {#change-the-key-key-rotation}

You should change `APP_KEY` from time to time, or when someone who knew it leaves the team. If you just change it, old cookies and sessions can not be read, so every user is logged out, and JWT tokens signed with it stop working. With `previousKeys`, users stay logged in while you change it:

1. Copy the current `APP_KEY` to `APP_PREVIOUS_KEYS`.
2. Run `dox key:generate`. It writes a new `APP_KEY`. Now `.env` has both:

    ```bash title=".env"
    APP_KEY=<the new key from dox key:generate>
    APP_PREVIOUS_KEYS=<the old APP_KEY>
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

`APP_PREVIOUS_KEYS` can hold more than one key, comma separated. Dox writes a cookie with the new key the next time it sends it, so a user who comes back during step 5 moves to the new key without noticing.

The old keys are used to read encrypted cookies, the `cookie` session driver, the CSRF token, `Crypt.decrypt`, and JWT tokens signed with `APP_KEY`. A JWT secret that is not `APP_KEY` needs its own `previousSecrets`, see [Authentication](authentication.md#change-the-jwt-secret). Your own `AESEncryptor.decode` calls read old keys only when you pass `previousSecrets: Dox().config.previousKeys`.

### When the key leaked

Do **not** put a leaked key in `previousKeys`, because anyone who has it can still make cookies and JWT tokens that Dox accepts. Change `APP_KEY` with no `previousKeys`. Every user is logged out, and that is what you want.

## Details

- To store passwords, do not encrypt them. Hash them. See [Hashing](hashing.md).
- `Crypt.encryptString(v)` gives the same as `AESEncryptor.encode(v, appKey)`.
- The flag `decryptServerError` makes a `DecryptException` a reported `500` instead of a `400`. See [Core flags](../reference/app-config.md#core-flags).
- `KeyDerivation.forAppKey(label)` gives the 32-byte key of a label.
- The work runs in Rust with the AES instructions of the CPU. One cookie takes about 1–2 µs.
- Each message gets a new random 12-byte nonce. The output is base64 of `nonce + encrypted text + tag`. The 16-byte tag makes `decode` throw if one byte is changed.
- `encode` and `decode` also take `associatedData`, like a cookie name. It is not in the output, but `decode` needs the same value.
