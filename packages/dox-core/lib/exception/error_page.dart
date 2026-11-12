import 'dart:convert';

import 'package:dox_core/dox_core.dart';

/// Makes the HTML of the error page, see `AppConfig.htmlErrors`.
/// [status] is the HTTP status. [debug] is true when `APP_ENV` is
/// `development` or `local`: then the page may show the error text and
/// the [stackTrace]. Escape every value you put in the page.
typedef ErrorPageRenderer = String Function(
  int status,
  Object error,
  StackTrace stackTrace,
  bool debug,
);

const HtmlEscape _escape = HtmlEscape();

/// The default error page: a small HTML page with the status and its
/// title, like `404 Not Found`. With [debug], it also shows the error
/// text and the stack trace. It loads no files from outside.
String defaultErrorPage(
  int status,
  Object error,
  StackTrace stackTrace,
  bool debug,
) {
  String title = _escape.convert('$status ${_title(status)}');
  String details = '';
  if (debug) {
    Object? message = error is IHttpException ? error.message : error;
    details =
        '<p>${_escape.convert('$message')}</p>'
        '<pre>${_escape.convert('$stackTrace')}</pre>';
  }
  return '<!doctype html><html lang="en"><head><meta charset="utf-8">'
      '<meta name="viewport" content="width=device-width, initial-scale=1">'
      '<title>$title</title><style>'
      'body{margin:0;padding:48px 16px;font-family:system-ui,sans-serif;'
      'color:#222;background:#fafafa}main{max-width:760px;margin:0 auto}'
      'h1{font-size:28px;font-weight:600}pre{white-space:pre-wrap;'
      'overflow:auto;font-size:13px;padding:12px;background:#fff;'
      'border:1px solid #ddd}</style></head>'
      '<body><main><h1>$title</h1>$details</main></body></html>';
}

/// the short name of an HTTP [status], like `Not Found` for 404.
/// `Error` for a status it does not know.
String _title(int status) => '${HttpStatusException(status).message}';
