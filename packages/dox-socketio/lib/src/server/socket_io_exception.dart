/// Throw it in a middleware to refuse a connection.
///
/// The client gets a `connect_error` with [message] and [data].
class SocketIoException implements Exception {
  const SocketIoException(this.message, {this.data});

  final String message;
  final Object? data;

  /// Payload of the CONNECT_ERROR packet.
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'message': message,
      if (data != null) 'data': data,
    };
  }

  @override
  String toString() => 'SocketIoException: $message';
}
