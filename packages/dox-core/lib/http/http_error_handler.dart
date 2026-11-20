import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:dox_core/http/http_response_handler.dart';
import 'package:dox_core/http/request/upload_temp_files.dart';
import 'package:dox_validation/dox_validation.dart' as dv;

/// Every error of a request comes here. The `ExceptionHandler` of
/// `AppConfig` reports it and decides the response.
void httpErrorHandler(HttpRequest req, Object error, StackTrace stackTrace) {
  /// the request failed: its upload temp files can go (after the answer)
  if (AfterResponse.enabled) AfterResponse.handlerEnded();
  releaseTempFiles(req);
  try {
    httpResponseHandler(renderError(req, error, stackTrace), req);
  } catch (sendError, sendStack) {
    /// the error answer failed too (eg. a bad header). report it and
    /// send a plain 500, so the client never waits for a timeout.
    try {
      Dox().config.exceptionHandler.report(sendError, sendStack);
    } catch (_) {
      Logger.danger(
        'Sending the error failed: $sendError\n$sendStack',
        null,
        'error',
      );
    }
    _plainError(req.response);
  }
}

/// a bare 500 with none of the headers set so far. When the head is
/// already sent, it only closes the response.
void _plainError(HttpResponse res) {
  if (headSent(res)) {
    try {
      endResponse(res);
    } catch (_) {
      /// client already gone
    }
    return;
  }
  try {
    res.headers.clear();
    res.statusCode = HttpStatus.internalServerError;
    res.headers.contentType = ContentType.text;
    res.add(_plainErrorBody);
  } catch (_) {
    /// the head is already sent
  }
  try {
    endResponse(res);
  } catch (_) {
    /// client already gone
  }
}

final List<int> _plainErrorBody = 'Internal Server Error'.codeUnits;

/// the requests of routes with `Route.renderErrorsWith`
final Expando<DoxRequest> _withRenderer = Expando<DoxRequest>();

/// keep [doxReq] so an error of [req] goes to the renderer of its route.
/// Only for a route that has one.
void keepForErrorRenderer(HttpRequest req, DoxRequest doxReq) {
  _withRenderer[req] = doxReq;
}

/// Report [error] and give the response for it, from the
/// `ExceptionHandler` of `AppConfig`. It is not sent yet.
dynamic renderError(HttpRequest req, Object error, StackTrace stackTrace) {
  /// `schema.parse()` in a controller: answer 422 like `req.validate()`
  if (error is dv.ValidationException) {
    error = ValidationException(message: error.errors, issues: error.issues);
  }
  ExceptionHandler handler = Dox().config.exceptionHandler;
  dynamic payload = error;
  try {
    /// 4xx answers are the client's fault, only 5xx are reported
    if (error is! IHttpException || error.code >= 500) {
      handler.reportFor(req, error, stackTrace);
    }

    /// the head is out (a flush or a stream, eg. server-sent events): the
    /// status and headers can not change, and an error text would land
    /// inside the body. the error is reported, and the answer just ends.
    if (headSent(req.response) || responseTakenOver(req)) return null;

    /// the route renders its own errors (`Route.renderErrorsWith`)
    DoxRequest? doxReq = _withRenderer[req];
    RouteErrorRenderer? renderer = doxReq?.route.errorRenderer;
    if (renderer != null) {
      DoxResponse? custom = renderer(error, doxReq!);
      if (custom != null) return custom;
      if (responseTakenOver(req)) return null;
    }
    payload = handler.render(error, req);
  } catch (handlerError, handlerStack) {
    /// a broken handler must not leave the client waiting.
    /// send the default answer for the first error.
    Logger.danger(
      'ExceptionHandler failed: $handlerError\n$handlerStack',
      null,
      'error',
    );
  }
  if (identical(payload, error)) payload = _htmlPage(req, error, stackTrace);
  return payload;
}

/// the HTML error page of `AppConfig.htmlErrors`, or [error] itself (the
/// JSON answer) when it is off, the client wants JSON, or it is a
/// validation error (it keeps its 422 JSON or its redirect).
Object _htmlPage(HttpRequest req, Object error, StackTrace stackTrace) {
  AppConfig config = Dox().config;
  if (!config.htmlErrors || error is ValidationException) return error;
  try {
    if (DoxRequest.expectsJsonFor(req.headers)) return error;
    int status = error is IHttpException
        ? error.code
        : HttpStatus.internalServerError;
    DoxResponse page = response(
      config.errorPage(status, error, stackTrace, showErrors()),
    ).statusCode(status).contentType(ContentType.html);
    if (error is HttpStatusException) page.withHeaders(error.headers);
    return page;
  } catch (pageError, pageStack) {
    /// a repeated header or a broken renderer: send the JSON answer
    Logger.danger(
      'The error page failed: $pageError\n$pageStack',
      null,
      'error',
    );
    return error;
  }
}
