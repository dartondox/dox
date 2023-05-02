import 'dart:io';

abstract class ExceptionHandler {
  handle(dynamic data, HttpResponse res);
}
