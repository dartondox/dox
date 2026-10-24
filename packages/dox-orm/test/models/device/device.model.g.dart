// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device.model.dart';

// **************************************************************************
// Generator: DoxModelBuilder
// **************************************************************************

// ignore_for_file: always_specify_types

class DeviceGenerator extends Model<Device> {
  @override
  String get primaryKey => 'uuid';

  @override
  Map<String, dynamic> get timestampsColumn => const <String, dynamic>{
    'created_at': 'created_at',
    'updated_at': 'updated_at',
  };

  String? get uuid => tempIdValue as String?;

  set uuid(String? val) => tempIdValue = val;

  Device query() => Device();

  @override
  bool get readsRowDates => true;

  @override
  List<String> get tableColumns => const <String>[
    'uuid',
    'name',
    'created_at',
    'updated_at',
  ];

  @override
  List<String> get preloadList => const <String>[];

  @override
  Map<String, Function> get relationsResultMatcher =>
      const <String, Function>{};

  @override
  Map<String, Function> get relationsQueryMatcher => const <String, Function>{};

  @override
  Device fromMap(Map<String, dynamic> m) => Device()
    ..uuid = m['uuid'] as String?
    ..name = m['name'] as String?
    ..createdAt = m['created_at'] is DateTime?
        ? m['created_at'] as DateTime?
        : DateTime.parse(m['created_at'] as String)
    ..updatedAt = m['updated_at'] is DateTime?
        ? m['updated_at'] as DateTime?
        : DateTime.parse(m['updated_at'] as String);
  @override
  Map<String, dynamic> columnsToMap() {
    Device instance = this as Device;
    Map<String, dynamic> map = <String, dynamic>{
      'uuid': instance.uuid,
      'name': instance.name,
      'created_at': instance.createdAt?.toIso8601String(),
      'updated_at': instance.updatedAt?.toIso8601String(),
    };

    return map;
  }

  @override
  Map<String, dynamic> convertToMap(dynamic i) {
    Device instance = i as Device;
    Map<String, dynamic> map = instance.columnsToMap();

    return map;
  }
}
