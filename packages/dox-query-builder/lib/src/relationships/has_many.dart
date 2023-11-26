import 'package:dox_query_builder/dox_query_builder.dart';

/// has many relationships query
M? hasMany<T, M>(
  List<Model<T>> list,
  Model<M> Function() model, {
  String? foreignKey,
  String? localKey,
  dynamic onQuery,
}) {
  if (list.isEmpty) return null;

  Model<T> owner = list.first;
  localKey = localKey ?? owner.primaryKey;
  foreignKey = foreignKey ?? "${owner.tableName}_id";

  List<String> ids = list.map((Model<T> i) {
    Map<String, dynamic> map = i.toMap();
    return map[localKey].toString();
  }).toList();

  Model<M> m = model().debug(owner.shouldDebug);

  m.select('*, $foreignKey as _owner_id').whereIn(foreignKey, ids);

  if (onQuery != null) {
    m = onQuery(m);
  }
  return m as M;
}

/// get has many relationships result
Future<Map<String, List<M>>> getHasMany<T, M>(
  dynamic q,
  List<Model<T>> list,
) async {
  if (q == null) return <String, List<M>>{}; // coverage:ignore-line
  List<M> results = await q.get();

  Map<String, List<M>> ret = <String, List<M>>{};

  /// filter matched values with local id value
  for (M r in results) {
    Map<String, dynamic> map = (r as Model<M>).toMap(original: true);
    String ownerId = map['_owner_id'].toString();
    if (ret[ownerId] == null) {
      ret[ownerId] = <M>[];
    }
    ret[ownerId]?.add(r);
  }

  /// to prevent result null instead return empty list
  for (Model<T> i in list) {
    ret[i.tempIdValue.toString()] = ret[i.tempIdValue.toString()] ?? <M>[];
  }

  return ret;
}
