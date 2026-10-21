import 'package:dox_core/dox_core.dart';
import 'package:dox_core/http/request/form_input.dart';
import 'package:dox_core/http/request/http_request_body.dart';

/// Finds a DTO schema by its type or class name.
///
/// It is made from `AppConfig(dtos: dtos)` (the list in `lib/dtos.g.dart`).
/// Dox does not use `dart:mirrors`, so this list is how it knows the DTOs.
class DtoRegistry {
  DtoRegistry(List<DtoSchema<Object>> dtos) {
    for (DtoSchema<Object> dto in dtos) {
      _byType[dto.type] = dto;
      _byName[dto.name] = dto;
    }
  }

  final Map<Type, DtoSchema<Object>> _byType = <Type, DtoSchema<Object>>{};
  final Map<String, DtoSchema<Object>> _byName = <String, DtoSchema<Object>>{};

  /// The DTO of [type], or null.
  DtoSchema<Object>? ofType(Type type) {
    return _byType[type];
  }

  /// The DTO with the class [name], or null.
  DtoSchema<Object>? ofName(String name) {
    return _byName[name];
  }
}

/// Checks request input with a DTO or a fluent schema.
///
/// A failed check throws the dox-core [ValidationException] (HTTP 422)
/// with `{"path": "message"}`.
class RequestValidator {
  const RequestValidator({this.forms = const FormInput()});

  final FormInput forms;

  /// Check the input of [req] with [schema] and give the object.
  /// [source] wins over the `source` of the DTO.
  Future<Object> validateDto(
    DoxRequest req,
    DtoSchema<Object> schema, {
    Source? source,
  }) async {
    Source from = source ?? schema.source;
    if (from == Source.auto) {
      String method = req.method;
      from = method == 'GET' || method == 'HEAD' || method == 'DELETE'
          ? Source.query
          : Source.body;
    }
    Object? input;
    bool text = true;
    if (from == Source.query) {
      input = forms.query(req.uri);
    } else {
      RequestBody body = req.requestBody;
      switch (body.kind) {
        case BodyKind.json:
          input = body.json;
          text = false;
        case BodyKind.none:
          input = <String, dynamic>{};
          text = false;
        case BodyKind.invalidJson:
          throw BadRequestException(message: 'The body is not valid JSON');
        case BodyKind.urlEncoded:
          input = forms.parse(_pairs(body.text ?? ''));
        case BodyKind.multipart:
          input = forms.parse(body.parts ?? const <MapEntry<String, Object>>[]);
        case BodyKind.other:
          throw UnsupportedMediaTypeException();
      }
    }
    DtoState state = DtoState(
      root: input,
      resolver: Dox().messages,
      params: req.pathParams,
      locale: req.locale,
      text: text,
    );
    ParseResult<Object> result = await schema.run(input, state);
    if (!result.success) throw ValidationException(message: result.errors);
    return result.value as Object;
  }

  /// Check [data] with any schema and give its typed output.
  Future<O> validateSchema<O>(Schema<O> schema, Object? data) async {
    ParseResult<O> result = schema.isAsync
        ? await schema.safeParseAsync(data, messages: Dox().messages)
        : schema.safeParse(data, messages: Dox().messages);
    if (!result.success) throw ValidationException(message: result.errors);
    return result.value as O;
  }

  List<MapEntry<String, Object>> _pairs(String text) {
    List<MapEntry<String, Object>> pairs = <MapEntry<String, Object>>[];
    if (text.isEmpty) return pairs;
    for (String part in text.split('&')) {
      if (part.isEmpty) continue;
      int equals = part.indexOf('=');
      String key = equals < 0 ? part : part.substring(0, equals);
      String value = equals < 0 ? '' : part.substring(equals + 1);
      try {
        pairs.add(
          MapEntry<String, Object>(
            Uri.decodeQueryComponent(key),
            Uri.decodeQueryComponent(value),
          ),
        );
      } on FormatException {
        throw BadRequestException(message: 'The form body is not valid');
      } on ArgumentError {
        throw BadRequestException(message: 'The form body is not valid');
      }
    }
    return pairs;
  }
}
