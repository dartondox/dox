---
icon: lucide/fingerprint
---

# Hashing

`Hash` turns a password into a bcrypt hash that you can store, and checks a password against it later.

A hash is one-way: you can not turn it back into the password. `Hash` uses bcrypt with a new random salt each time. It is in `package:dox_core/dox_core.dart`.

You do not need `Hash` for a normal login, because `Auth().attempt()` from `dox_auth` checks the password for you. See [Authentication](authentication.md).

## Hashing passwords

Hash the password before you save it:

```dart
user.password = await Hash.makeAsync(body.password);
await user.save();
```

`makeAsync` runs bcrypt in another isolate, so it does not block the server. The result looks like `$2a$10$...`. It holds the salt, so you only store this one string.

Never send the hash to the client. Put the column in the `hidden` list of the model.

## Verifying passwords

Use `verifyAsync` to check a password against a hash. It gives `true` when they match:

```dart
bool ok = await Hash.verifyAsync('secret', user.password!);
```

It gives `false` when the password does not match, or when the hash is not a valid bcrypt hash, like an empty string.

`Hash.make` and `Hash.verify` do the same, but they block the request isolate while bcrypt runs. Use them only outside request handlers. `Hash.check` is the same as `Hash.verify`:

```dart
bool ok = Hash.verify('secret', user.password!);
```

## Changing the cost

`Hash.rounds` is the bcrypt cost for new hashes. The default is `10`, and each step up doubles the time. The cost must be from 4 to 31. Do not go below 10:

```dart
Hash.rounds = 12;
String hash = Hash.make('secret', rounds: 12); // or per call
```

Old hashes keep their own cost, so they still verify. If you change the cost, also set `hashRounds` on your auth driver to the same value. See [Authentication](authentication.md#password-hash-cost).

## Long passwords

bcrypt reads at most 72 bytes. So `Hash.make` and `Hash.makeAsync` throw an `ArgumentError` for a longer password, and `Hash.verify` gives `false`. Limit the length in your DTO, like `@Length(min: 8, max: 72)`.

`@Length` counts characters, but a letter outside ASCII can use up to 4 bytes. So such a password can still be too long. Catch the error and answer `422`, or use a smaller `max`.

## Comparing secrets

To check an API key or a token, use `Hash.equals(given, expected)`, not `==`. `==` stops at the first wrong character, so the time can tell how much of the key was right. `Hash.equals` takes the same time for every value of the same length:

```dart
bool ok = Hash.equals(req.header('X-Api-Key') ?? '', Env.get<String>('API_KEY'));
```

## Storing tokens

For a long random secret that you keep in the database, like an API key, store only `Hash.sha256(token)`. Then find the row by the hash of what the client sends. SHA-256 gives the same hash for the same input, so a unique index works on it:

```dart
String stored = Hash.sha256(token);          // save this, never the token
Token? row = await Token().where('hash', Hash.sha256(given)).getFirst();
```

Never use `Hash.sha256` for passwords. A password is short and can be guessed, so use bcrypt.

## Details

- The error text of a too long password does not hold the password, so it is safe in logs.
- bcrypt is slow on purpose, so guessing is slow too. Do not hash in a loop on hot paths.

## See also

- [Encryption](encryption.md): hide data that you must read again.
- [Authentication](authentication.md): login with hashed passwords.
