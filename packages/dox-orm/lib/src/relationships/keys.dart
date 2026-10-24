import 'package:dox_orm/dox_orm.dart';

/// the value of [key] in [model]. the primary key is read without
/// making a map.
dynamic relationKey(Model<dynamic> model, String key) {
  return key == model.primaryKey
      ? model.tempIdValue
      : model.columnsToMap()[key];
}

/// the values of [key] in [list], each once and without null
List<dynamic> relationKeys(List<Model<dynamic>> list, String key) {
  return <dynamic>{for (Model<dynamic> i in list) relationKey(i, key)}
      .where(_notNull)
      .toList();
}

bool _notNull(dynamic value) => value != null;
