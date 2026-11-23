---
icon: lucide/fingerprint
---

# Hashing

`Hash` turns a password into a bcrypt hash that you can store, and checks a password against it later.

A **hash** is one-way: you can not turn it back into the password. `Hash` is in `package:dox_core/dox_core.dart`. For a normal login you do not need it, because `Auth().attempt()` checks the password. See [Authentication](authentication.md).

## Hashing passwords

Hash the password before you save it. `makeAsync` runs bcrypt in another isolate, so the server does not wait:

```dart
user.password = await Hash.makeAsync(body.password);
await user.save();
```

The result, like `$2a$10$...`, holds the salt, so you store only this one string.

!!! warning
    Never send the hash to the client. Put the column in the `hidden` list of the model.

## Verifying passwords

`verifyAsync` gives true when the password matches the hash. It gives false for a wrong password or a hash that is not bcrypt:

```dart
bool ok = await Hash.verifyAsync('secret', user.password!);
```

### Outside a request

`Hash.make` and `Hash.verify` do the same, but they block the isolate while bcrypt runs. Use them only outside request handlers. `Hash.check` is the same as `Hash.verify`:

```dart
String hash = Hash.make('secret');
bool ok = Hash.verify('secret', hash);
```

## Changing the cost

`Hash.rounds` is the bcrypt cost for new hashes, from 4 to 31. The default is 10, and each step up doubles the time. Do not go below 10:

```dart
Hash.rounds = 12;
String hash = Hash.make('secret', rounds: 12); // or per call
```

Old hashes keep their cost, so they still verify. Also set `hashRounds` on your auth driver to the same value. See [Authentication](authentication.md#password-hash-cost).

## Long passwords

bcrypt reads at most 72 bytes. `Hash.make` and `Hash.makeAsync` throw an `ArgumentError` for a longer password, and `Hash.verify` gives false. Limit the length in your DTO:

```dart
@Length(min: 8, max: 72)
String password;
```

`@Length` counts characters, and a letter outside ASCII can use up to 4 bytes. So catch the error and answer 422, or use a smaller `max`.

## Comparing secrets

To check an API key or a token, use `Hash.equals`, not `==`. It takes the same time for every value of the same length, so the time does not tell how much of the key was right:

```dart
bool ok = Hash.equals(req.header('X-Api-Key') ?? '',
    Env.get<String>('API_KEY'));
```

## Storing tokens

For a long random secret in the database, like an API key, store only `Hash.sha256(token)`. Then find the row by the hash of what the client sends:

```dart
String stored = Hash.sha256(token);          // save this, never the token
Token? row = await Token().where('hash', Hash.sha256(given)).getFirst();
```

!!! warning
    Never use `Hash.sha256` for passwords. A password is short and easy to guess, so use bcrypt.

## Next steps

- [Encryption](encryption.md): hide data that you must read again.
- [Authentication](authentication.md): login with hashed passwords.
