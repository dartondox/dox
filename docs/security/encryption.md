# Encryption

This page shows how to encrypt and decrypt text with `AESEncryptor`.

Dox uses `AESEncryptor` to encrypt cookies with your `APP_KEY`.
You can also call it yourself.

## Encrypt and decrypt

`AESEncryptor` is not exported by `package:dox_core/dox_core.dart`. Import it from its own file.

```dart
import 'package:dox_core/utils/aes_encryptor.dart';

String secret = env.appKey; // 32 characters

String encoded = AESEncryptor.encode('Hello world', secret);
String decoded = AESEncryptor.decode(encoded, secret); // 'Hello world'
```

- `encode` returns base64 text.
- `decode` returns an empty string `''` when the text or the key is wrong. It does not throw.
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

If you change `APP_KEY`, old encrypted cookies read as `''`.

## Limits

!!! warning "Do not use it for sensitive data"
    `AESEncryptor` uses AES in CTR mode with a fixed IV (all zeros).
    It has no message check (no MAC).

    - The same text with the same key always gives the same output. So a reader can see when two values are equal.
    - Someone can change the encrypted text, and `decode` does not notice.

    This keeps old cookies working. But it is not safe for passwords, tokens or personal data.
    For those, use a library with an authenticated mode, like AES-GCM with a random nonce for each message.

To store passwords, do not encrypt them. Hash them. See [Hashing](hashing.md).
