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

String secret = env.appKey; // 32 characters

String encoded = AESEncryptor.encode('Hello world', secret);
String decoded = AESEncryptor.decode(encoded, secret); // 'Hello world'
```

- `encode` returns base64 text.
- The same text gives a different output each time.
- `decode` throws `DecryptException` when the text was changed, or the key is wrong. It is a `400 Bad Request` error.
- The secret must be 16, 24 or 32 bytes long (AES-128, AES-192 or AES-256). Another length makes `encode` throw.

Make a new 32-character `APP_KEY` with the CLI:

```bash
dox key:generate
```

## Cookies

`DoxCookie` encrypts its value with `APP_KEY` by default.
`req.cookie(key)` decrypts it.

```dart
return response().cookie(DoxCookie('theme', 'dark'));  // encrypted
DoxCookie('theme', 'dark', encrypt: false);             // plain text

String? theme = req.cookie('theme');                    // decrypted
String? raw = req.cookie('theme', decrypt: false);      // as sent
```

`req.cookie(key)` returns `null` when the cookie was changed, was made with another `APP_KEY`, or was made for another cookie name.
The cookie name is bound to the encrypted value, so a value can not be copied from one cookie to another.

## How it works

`AESEncryptor` uses AES-GCM.

- Each message gets a new random 12-byte nonce.
- The output is base64 of `nonce + encrypted text + tag`.
- The 16-byte tag checks the message. If someone changes one byte, `decode` throws.

To store passwords, do not encrypt them. Hash them. See [Hashing](hashing.md).
