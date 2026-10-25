// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cast_item.model.dart';

// **************************************************************************
// Generator: DoxModelBuilder
// **************************************************************************

// ignore_for_file: always_specify_types

class CastItemGenerator extends Model<CastItem> {
  @override
  String get primaryKey => 'id';

  @override
  Map<String, dynamic> get timestampsColumn => const <String, dynamic>{
    'created_at': null,
    'updated_at': null,
  };

  int? get id => tempIdValue as int?;

  set id(int? val) => tempIdValue = val;

  CastItem query() => CastItem();

  @override
  bool get readsRowDates => true;

  @override
  List<String> get tableColumns => const <String>[
    'id',
    'meta',
    'tags',
    'active',
    'done',
    'status',
    'level',
    'price',
  ];

  @override
  List<String> get preloadList => const <String>[];

  @override
  Map<String, Function> get relationsResultMatcher =>
      const <String, Function>{};

  @override
  Map<String, Function> get relationsQueryMatcher => const <String, Function>{};

  static const _metaCast = JsonCast();
  static const _tagsCast = ListCast<String>();
  static const _activeCast = BoolCast();
  static const _doneCast = BoolCast();
  static const _statusCast = EnumCast(Status.values);
  static const _levelCast = EnumCast<Level>(Level.values, byIndex: true);
  static const _priceCast = MoneyCast();

  @override
  CastItem fromMap(Map<String, dynamic> m) => CastItem()
    ..id = m['id'] as int?
    ..meta = _metaCast.get(m['meta'])
    ..tags = _tagsCast.get(m['tags'])
    ..active = _activeCast.get(m['active'])
    ..done = _doneCast.get(m['done']) as bool
    ..status = _statusCast.get(m['status'])
    ..level = _levelCast.get(m['level'])
    ..price = _priceCast.get(m['price']);
  @override
  Map<String, dynamic> columnsToMap() {
    CastItem instance = this as CastItem;
    Map<String, dynamic> map = <String, dynamic>{
      'id': instance.id,
      'meta': _metaCast.set(instance.meta),
      'tags': _tagsCast.set(instance.tags),
      'active': _activeCast.set(instance.active),
      'done': _doneCast.set(instance.done),
      'status': _statusCast.set(instance.status),
      'level': _levelCast.set(instance.level),
      'price': _priceCast.set(instance.price),
    };

    return map;
  }

  @override
  Map<String, dynamic> convertToMap(dynamic i) {
    CastItem instance = i as CastItem;
    Map<String, dynamic> map = instance.columnsToMap();

    return map;
  }
}
