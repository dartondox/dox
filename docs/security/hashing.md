# Hashing

This page shows how to hash passwords with `Hash` and check them later.

A hash is one-way. You can not turn it back into the password.
To check a login, hash the new input and compare. `Hash.verify` does this for you.
`Hash` uses bcrypt with a new random salt each time.

`Hash` is in `package:dox_core/dox_core.dart`.

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

## With login

You do not need `Hash.verify` for normal login.
`Auth().attempt()` from `dox_auth` finds the user and checks the password with bcrypt.
See [Authentication](authentication.md).

## Things to know

- Never store a plain password. Never encrypt a password. Hash it.
- Never send the hash to the client. Put the column in the model `hidden` list.
- bcrypt is slow on purpose. This makes guessing many passwords slow too. Do not hash in a loop on hot paths.
