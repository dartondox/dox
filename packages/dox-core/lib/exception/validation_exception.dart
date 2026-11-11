import 'dart:io';

import 'package:dox_core/dox_core.dart';

class ValidationException extends IHttpException {
  ValidationException({
    dynamic message = const <String, dynamic>{},
    String errorCode = 'validation_failed',
    int code = HttpStatus.unprocessableEntity,
    this.issues = const <ValidationIssue>[],
  }) {
    super.code = code;
    super.errorCode = errorCode;
    super.message = message;
  }

  /// Every issue of the failed check, with its path, rule `code`, message
  /// and params. [message] has only the first message of each path.
  /// An `ExceptionHandler` can use it to send another error shape, like
  /// `[{field, message, rule}]`. Empty when the error was made by hand.
  final List<ValidationIssue> issues;

  /// The 422 body. With `CoreFlags.laravelErrors` it is
  /// `{"message": "...", "errors": {"field": ["..."]}}`, else [message].
  @override
  dynamic toResponse() {
    if (!Dox().flags.laravelErrors) return super.toResponse();
    Map<String, List<String>> errors = _allErrors();
    List<String> all = <String>[
      for (List<String> list in errors.values) ...list,
    ];
    String text = all.isEmpty ? message.toString() : all.first;
    int more = all.length - 1;
    if (more > 0) text += ' (and $more more error${more == 1 ? '' : 's'})';
    return <String, dynamic>{'message': text, 'errors': errors};
  }

  /// All messages of each field: from [issues], else from a [message] map.
  Map<String, List<String>> _allErrors() {
    if (issues.isNotEmpty) return IssueMaps.allErrors(issues);
    Object? map = message;
    if (map is! Map) return <String, List<String>>{};
    return <String, List<String>>{
      for (MapEntry<dynamic, dynamic> e in map.entries)
        '${e.key}': e.value is Iterable
            ? <String>[for (Object? m in e.value as Iterable<dynamic>) '$m']
            : <String>['${e.value}'],
    };
  }
}
