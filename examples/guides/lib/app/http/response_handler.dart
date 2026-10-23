import 'dart:io';

import 'package:dox_core/dox_core.dart';

/// Gives every error the same JSON shape:
/// `{"error": {"code": "not_found", "message": "..."}}`.
/// A validation error (422) also has `"errors": {field: message}`.
class ResponseHandler extends ResponseHandlerInterface {
  @override
  DoxResponse handle(DoxResponse res) {
    dynamic content = res.getContent();

    if (content is ValidationException) {
      return res.statusCode(content.code).content(<String, dynamic>{
        'error': <String, dynamic>{
          'code': content.errorCode,
          'message': 'The input is not valid',
        },
        'errors': content.message,
      });
    }

    if (content is IHttpException) {
      return res.statusCode(content.code).content(<String, dynamic>{
        'error': <String, dynamic>{
          'code': content.errorCode,
          'message': content.message.toString(),
        },
      });
    }

    // any other exception: hide the details from the client
    if (content is Exception || content is Error) {
      return res.statusCode(HttpStatus.internalServerError).content(
        <String, dynamic>{
          'error': <String, String>{
            'code': 'server_error',
            'message': 'Something went wrong',
          },
        },
      );
    }

    return res;
  }
}
