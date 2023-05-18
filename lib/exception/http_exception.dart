abstract class BaseHttpException {
  int code = 500;
  String errorCode = 'server_error';
  String message = 'Server Error';

  Map<String, dynamic> toMap() {
    return {
      "code": code,
      "error_code": errorCode,
      "message": message,
    };
  }
}
