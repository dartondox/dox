// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'city.dart';

// **************************************************************************
// DoxDtoGenerator
// **************************************************************************

// ignore_for_file: type=lint

/// The checks, the converter and the JSON Schema of [RvCity].
const DtoSchema<RvCity> $RvCityDto = _$RvCityDto();

class _$RvCityDto extends DtoSchema<RvCity> implements JsonObjectWriter {
  const _$RvCityDto();

  static const Map<String, String> _messages = <String, String>{};

  static final JsonRun _nameKey = JsonRun('{"name":');
  static final JsonRun _end = JsonRun('}');

  @override
  Type get type => RvCity;

  @override
  String get name => 'RvCity';

  @override
  bool get usesRequiredWhen => false;

  @override
  RvCity? convert(Object? input, DtoState state, List<Object> path) {
    if (input is! Map) {
      state.notObject(input, path, _messages);
      return null;
    }
    int issuesBefore = state.issues.length;
    // name: String
    Object? name = state.string(
      state.read(input, 'name'),
      path,
      'name',
      _messages,
    );
    if (name == null || name is Undefined)
      state.required(path, 'name', _messages);
    if (state.issues.length != issuesBefore && !state.allErrors) return null;
    if (state.issues.length != issuesBefore) return null;
    return RvCity(name: name as String);
  }

  @override
  RvCity fromMap(Map<String, dynamic> map) {
    return RvCity(name: map['name'] as String);
  }

  @override
  Map<String, dynamic> toMap(RvCity dto) {
    return <String, dynamic>{'name': dto.name};
  }

  @override
  void writeObject(Object object, JsonWriter writer) =>
      $writeRvCity(object as RvCity, writer);

  @override
  Map<String, dynamic> toJsonSchema() {
    return <String, dynamic>{
      'type': 'object',
      'title': 'RvCity',
      'properties': <String, dynamic>{
        'name': <String, dynamic>{'type': 'string'},
      },
      'required': <dynamic>['name'],
    };
  }
}

/// Writes the JSON of [RvCity], as `toMap()` gives it.
void $writeRvCity(RvCity dto, JsonWriter writer) {
  writer.run(_$RvCityDto._nameKey);
  writer.string(dto.name);
  writer.run(_$RvCityDto._end);
}
