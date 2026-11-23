---
icon: lucide/lock-keyhole
---

# Encryption

`Crypt` and `AESEncryptor` encrypt and decrypt text with AES-256-GCM, so you can store or send data that nobody else can read or change.

Dox uses the same encryption for cookies and the cookie session driver, with your `APP_KEY`. To store passwords, do not encrypt them: [hash](hashing.md) them.

## Setup

The key is `APP_KEY` in `.env`. Make a new random key of 32 letters and digits with the CLI:

```bash
dox key:generate
```

!!! warning
    Keep `APP_KEY` in `.env` or in the secrets of your host. Never put it in code or in git.

The app stops at startup when `APP_KEY` is empty, is not 32 bytes, or is a public sample key. In `development`, `local`, `test` and `testing` it only prints a warning.

## Encrypting values

`Crypt` uses the `APP_KEY` of the app. Use `encryptString` for text, and `encrypt` for any JSON value:

```dart
String secret = Crypt.encryptString('card-1234');

String data = Crypt.encrypt(<String, dynamic>{'id': 5});
```

The result is base64 text. The same value gives a different result each time.

## Decrypting values

Use `decryptString` or `decrypt` to get the value back:

```dart
String card = Crypt.decryptString(secret); // 'card-1234'

Map<String, dynamic> map = Crypt.decrypt(data);
```

A changed text, or a text made with another key, throws a `DecryptException`, and the client gets 400. The old keys in `previousKeys` also work, see [Rotating the key](#change-the-key-key-rotation).

The flag `decryptServerError` makes this error a reported 500. See [Core flags](../reference/app-config.md#core-flags).

## Using your own key

Use `AESEncryptor` to encrypt with a key that is not `APP_KEY`:

```dart
import 'package:dox_core/dox_core.dart';

String encoded = AESEncryptor.encode('Hello world', secret);
String decoded = AESEncryptor.decode(encoded, secret); // 'Hello world'
```

`decode` throws a `DecryptException` when the text was changed or the key is wrong. To also try old keys, give `previousSecrets: Dox().config.previousKeys`.

### One key per purpose

Dox makes a 32-byte key from your key and a label (the **purpose**). Give each use its own `purpose`, so a value made for one use does not work for another. `decode` needs the same `purpose`:

```dart
AESEncryptor.encode(text, secret, purpose: 'app:invoice');
```

Dox uses these labels for its own keys:

| Label | Used for |
| --- | --- |
| `dox:cookie` | encrypted cookies, and the cookie session driver |
| `dox:jwt` | the HMAC key of `JwtAuthDriver` (with a `SecretKey`) |
| `dox:encrypt` | `AESEncryptor` when you give no `purpose` |
| `dox:signed-url` | signed URLs |

To get the raw 32-byte key of a label, use `KeyDerivation.derive(secret, label)`, or `KeyDerivation.forAppKey(label)` for `APP_KEY`.

### Associated data

`encode` and `decode` also take `associatedData`, like a cookie name. It is not in the output, but `decode` needs the same value:

```dart
String encoded = AESEncryptor.encode(text, secret, associatedData: 'theme');
AESEncryptor.decode(encoded, secret, associatedData: 'theme');
```

## Encrypted cookies

`DoxCookie` encrypts its value with `APP_KEY` by default, and `req.cookie(key)` decrypts it:

```dart
return response().cookie(DoxCookie('theme', 'dark'));  // encrypted

String? theme = req.cookie('theme');                    // decrypted
```

For a plain text cookie, set `encrypt: false`. Read the raw value with `decrypt: false`:

```dart
DoxCookie('theme', 'dark', encrypt: false);             // plain text

String? raw = req.cookie('theme', decrypt: false);      // as sent
```

`req.cookie(key)` gives null when the cookie was changed, was made with another key, or was made for another cookie name. To decrypt a raw cookie value yourself, use `DoxCookie.decrypt(name, value)`.

## Rotating the key {#change-the-key-key-rotation}

Change `APP_KEY` from time to time, or when a person who knew it leaves the team. A new key alone logs out every user and stops JWT tokens signed with the old key. With `previousKeys`, users stay logged in:

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
5. Wait until the old cookies expire: the session `lifetime`, and the `maxAge` of your own cookies.
6. Remove the old key from `APP_PREVIOUS_KEYS` and deploy again.

`APP_PREVIOUS_KEYS` can hold many keys, with commas between them. Dox writes a cookie again with the new key the next time it sends it.

The old keys read encrypted cookies, the cookie session driver, the CSRF token, `Crypt.decrypt`, and JWT tokens signed with `APP_KEY`. A JWT secret that is not `APP_KEY` needs its own `previousSecrets`, see [Authentication](authentication.md#change-the-jwt-secret).

### When the key leaked

!!! warning
    Do not put a leaked key in `previousKeys`. A person who has it can make cookies and JWT tokens that Dox accepts. Change `APP_KEY` with no `previousKeys`. This logs out every user.

## Next steps

- [Hashing](hashing.md): store passwords.
- [Signed URLs](signed-urls.md): links that nobody can change.
- [Session](../the-basic/session.md): the cookie session driver.
