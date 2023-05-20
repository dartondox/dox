abstract class HttpException {
  int code = 500;
  String errorCode = 'server_error';
  dynamic message = 'Server Error';

  @override
  String toString() {
    return message.toString();
  }
}
