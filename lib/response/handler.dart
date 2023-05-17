import 'dart:io';

abstract class Handler {
  handle(dynamic data, HttpResponse res);
}
