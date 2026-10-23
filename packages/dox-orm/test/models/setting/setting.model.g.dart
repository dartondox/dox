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
  Map<String, dynamic> get timestampsColumn => <String, dynamic>{
    'created_at': null,
    'updated_at': null,
  };

  int? get id => tempIdValue as int?;

  set id(int? val) => tempIdValue = val;

  Setting query() => Setting();

  @override
  List<String> get tableColumns => <String>['id', 'name'];

  @override
  List<String> get preloadList => <String>[];

  @override
  Map<String, Function> get relationsResultMatcher => <String, Function>{};

  @override
  Map<String, Function> get relationsQueryMatcher => <String, Function>{};

  @override
  Setting fromMap(Map<String, dynamic> m) => Setting()
    ..id = m['id'] as int?
    ..name = m['name'] as String?;

  @override
  Map<String, dynamic> convertToMap(dynamic i) {
    Setting instance = i as Setting;
    Map<String, dynamic> map = <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
    };

    return map;
  }
}
