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

/// true while withCount() makes a relation query. the relation query
/// then matches the parent row with a column compare (not with the ids
/// of loaded models), so it can run as a subquery.
bool relationSubquery = false;

/// the condition `child.foreignKey = parent.localKey` of a subquery
String subqueryMatch(
  Model<dynamic> child,
  String childColumn,
  Model<dynamic> parent,
  String parentColumn,
) {
  return '${child.helper.wrap(childColumn)} = '
      '${child.helper.wrap('${parent.tableName}.$parentColumn')}';
}
