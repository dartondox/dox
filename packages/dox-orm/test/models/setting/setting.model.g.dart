// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'setting.model.dart';

// **************************************************************************
// Generator: DoxModelBuilder
// **************************************************************************

// ignore_for_file: always_specify_types

class SettingGenerator extends Model<Setting> {
  @override
  String get primaryKey => 'id';

  @override
  Map<String, dynamic> get timestampsColumn => const <String, dynamic>{
    'created_at': null,
    'updated_at': null,
  };

  int? get id => tempIdValue as int?;

  set id(int? val) => tempIdValue = val;

  Setting query() => Setting();

  @override
  bool get readsRowDates => true;

  @override
  List<String> get tableColumns => const <String>['id', 'name'];

  @override
  List<String> get preloadList => const <String>[];

  @override
  Map<String, Function> get relationsResultMatcher =>
      const <String, Function>{};

  @override
  Map<String, Function> get relationsQueryMatcher => const <String, Function>{};

  @override
  Setting fromMap(Map<String, dynamic> m) => Setting()
    ..id = m['id'] as int?
    ..name = m['name'] as String?;
  @override
  Map<String, dynamic> columnsToMap() {
    Setting instance = this as Setting;
    Map<String, dynamic> map = <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
    };

    return map;
  }

  @override
  Map<String, dynamic> convertToMap(dynamic i) {
    Setting instance = i as Setting;
    Map<String, dynamic> map = instance.columnsToMap();

    return map;
  }
}
