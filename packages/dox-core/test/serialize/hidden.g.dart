// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hidden.dart';

// **************************************************************************
// DoxSerializeGenerator
// **************************************************************************

// ignore_for_file: type=lint, unnecessary_null_comparison

/// The JSON writer of [HiddenSer]. Dox gets it from
/// `lib/generated/container.g.dart`.
const SerializeWriter $HiddenSerWriter = _$HiddenSerWriter();

class _$HiddenSerWriter implements SerializeWriter {
  const _$HiddenSerWriter();

  static final JsonRun _tKey = JsonRun('{"t":');
  static final JsonRun _tsKey = JsonRun(',"ts":');
  static final JsonRun _end = JsonRun('}');
  static final JsonRun _listStart = JsonRun('[');
  static final JsonRun _listEnd = JsonRun(']');

  @override
  Type get type => HiddenSer;

  @override
  void writeObject(Object object, JsonWriter writer) =>
      $writeHiddenSer(object as HiddenSer, writer);

  @override
  Object? toJsonValue(Object object) => (object as HiddenSer).toJson();
}

/// Writes the JSON of [HiddenSer], as `toJson()` gives it.
void $writeHiddenSer(HiddenSer serializer, JsonWriter writer) {
  List<Thing>? items = Serializer.listOf(serializer);
  if (items == null) {
    if (Serializer.hasItem(serializer)) {
      $writeHiddenSer$item(Serializer.itemOf(serializer), writer);
    } else {
      writer.value(null);
    }
    return;
  }
  writer.run(_$HiddenSerWriter._listStart);
  for (int i = 0; i < items.length; i++) {
    if (i > 0) writer.run(JsonRun.comma);
    $writeHiddenSer$item(items[i], writer);
  }
  writer.run(_$HiddenSerWriter._listEnd);
}

/// Writes the map of `convert()` of [HiddenSer].
void $writeHiddenSer$item(Thing m, JsonWriter writer) {
  writer.run(_$HiddenSerWriter._tKey);
  writer.value(ThingSer(m));
  writer.run(_$HiddenSerWriter._tsKey);
  writer.value(ThingSer(<Thing>[m]));
  writer.run(_$HiddenSerWriter._end);
}

/// The JSON writer of [HiddenPlain]. Dox gets it from
/// `lib/generated/container.g.dart`.
const SerializeWriter $HiddenPlainWriter = _$HiddenPlainWriter();

class _$HiddenPlainWriter implements SerializeWriter {
  const _$HiddenPlainWriter();

  static final JsonRun _pKey = JsonRun('{"p":');
  static final JsonRun _cityKey = JsonRun(',"city":');
  static final JsonRun _end = JsonRun('}');

  @override
  Type get type => HiddenPlain;

  @override
  void writeObject(Object object, JsonWriter writer) =>
      $writeHiddenPlain(object as HiddenPlain, writer);

  @override
  Object? toJsonValue(Object object) =>
      $HiddenPlainToMap(object as HiddenPlain);
}

/// Writes the JSON of [HiddenPlain], as `toMap()` gives it.
void $writeHiddenPlain(HiddenPlain dto, JsonWriter writer) {
  writer.run(_$HiddenPlainWriter._pKey);
  writer.value(dto.p);
  writer.run(_$HiddenPlainWriter._cityKey);
  writer.value(dto.city);
  writer.run(_$HiddenPlainWriter._end);
}

/// The JSON of [HiddenPlain] as a map.
Map<String, dynamic> $HiddenPlainToMap(HiddenPlain dto) {
  return <String, dynamic>{'p': dto.p, 'city': dto.city};
}

/// The JSON writer of [HiddenCity]. Dox gets it from
/// `lib/generated/container.g.dart`.
const SerializeWriter $HiddenCityWriter = _$HiddenCityWriter();

class _$HiddenCityWriter implements SerializeWriter {
  const _$HiddenCityWriter();

  static final JsonRun _cityKey = JsonRun('{"city":');
  static final JsonRun _citiesKey = JsonRun(',"cities":');
  static final JsonRun _end = JsonRun('}');

  @override
  Type get type => HiddenCity;

  @override
  void writeObject(Object object, JsonWriter writer) =>
      $writeHiddenCity(object as HiddenCity, writer);

  @override
  Object? toJsonValue(Object object) => $HiddenCityToMap(object as HiddenCity);
}

/// Writes the JSON of [HiddenCity], as `toMap()` gives it.
void $writeHiddenCity(HiddenCity dto, JsonWriter writer) {
  writer.run(_$HiddenCityWriter._cityKey);
  writer.value(dto.city);
  writer.run(_$HiddenCityWriter._citiesKey);
  writer.value(dto.cities);
  writer.run(_$HiddenCityWriter._end);
}

/// The JSON of [HiddenCity] as a map.
Map<String, dynamic> $HiddenCityToMap(HiddenCity dto) {
  return <String, dynamic>{'city': dto.city, 'cities': dto.cities};
}
