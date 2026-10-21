/// Base class for every error thrown by dox_storage.
class StorageException implements Exception {
  /// The file key (or prefix) the error is about.
  final String key;

  /// Plain-English message.
  final String message;

  /// The original error from the driver, if any.
  final Object? cause;

  const StorageException(this.key, this.message, {this.cause});

  @override
  String toString() {
    String text = '$runtimeType: $message (key: "$key")';
    if (cause != null) {
      text += '\nCaused by: $cause';
    }
    return text;
  }
}

/// The file does not exist.
class FileNotFoundException extends StorageException {
  const FileNotFoundException(String key, {Object? cause})
      : super(key, 'File not found', cause: cause);
}

/// The driver is not allowed to do this (file system permissions, S3 403).
class PermissionDeniedException extends StorageException {
  const PermissionDeniedException(String key, {Object? cause})
      : super(key, 'Permission denied', cause: cause);
}

/// The key is not safe, for example it uses `..` or an absolute path.
class InvalidKeyException extends StorageException {
  const InvalidKeyException(String key, String reason)
      : super(key, 'Invalid key: $reason');
}

/// The driver does not support this operation.
class UnsupportedOperationException extends StorageException {
  const UnsupportedOperationException(String key, String message)
      : super(key, message);
}

/// Any other driver failure (network error, S3 500, disk full, ...).
class DriverException extends StorageException {
  const DriverException(String key, String message, {Object? cause})
      : super(key, message, cause: cause);
}
