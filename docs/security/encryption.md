# Encryption

## Encode

```dart
String encodedMessage = AESEncryptor.encode('Hello world', 'your-secret');
print(encodedMessage);
```

## Decode

```dart
String decodedMessage = AESEncryptor.decode(encodedMessage, 'your-secret');
print(decodedMessage);
```