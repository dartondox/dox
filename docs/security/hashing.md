# Hashing

The Dox Hash class provides the capability to utilize bcrypt for hashing values.

## Hash a password

```dart
String secret = 'password';
String hashedPassword = Hash.make(secret);
```

## Verify hashed password

```dart
String secret = 'password';
bool verified = Hash.verify(secret, hashedPassword);
```