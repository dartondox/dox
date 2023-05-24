abstract class HttpException {
  int code = 500;
  String errorCode = 'server_error';
  dynamic message = 'Server Error';

  dynamic toResponse() {
    if (message is Map) {
      return message;
    }
    return message.toString();
  }
}
