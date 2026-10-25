# Hashing

This page shows how to hash passwords with `Hash` and check them later.

A hash is one-way. You can not turn it back into the password.
`Hash` uses bcrypt with a new random salt each time. It is in `package:dox_core/dox_core.dart`.

## Hash a password

Hash the password before you save it.

```dart
user.password = Hash.make(body.password);
await user.save();
```

The result looks like `$2a$10$...`. It holds the salt, so you only store this one string.
The same password gives a different hash each time.

## Check a password

```dart
bool ok = Hash.verify('secret', user.password!);
```

`Hash.verify(password, hashedPassword)` returns `true` when the password matches.
It returns `false` when the password does not match, or when `hashedPassword` is not a valid bcrypt hash (for example an empty string).

## Without blocking the server

`Hash.make` and `Hash.verify` block the request isolate while bcrypt runs.
In a request handler, use the async versions. They run bcrypt in another isolate.

```dart
user.password = await Hash.makeAsync(body.password);
bool ok = await Hash.verifyAsync('secret', user.password!);
```

## Cost

`Hash.rounds` is the bcrypt cost for new hashes. The default is `10`. Each step up doubles the time.

```dart
Hash.rounds = 12;
String hash = Hash.make('secret', rounds: 12); // or per call
```

Old hashes keep their own cost, so they still verify.
If you change it, also set `hashRounds` on `JwtAuthDriver` to the same value. See [Authentication](authentication.md).

## With login

You do not need `Hash.verify` for normal login.
`Auth().attempt()` from `dox_auth` finds the user and checks the password with bcrypt.
See [Authentication](authentication.md).

## Things to know

- Never store or encrypt a plain password. Hash it.
- Never send the hash to the client. Put the column in the model `hidden` list.
- bcrypt is slow on purpose, so guessing is slow too. Do not hash in a loop on hot paths.
