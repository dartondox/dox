import 'package:dox_query_builder/dox_query_builder.dart';

/// one to one relationship query
M? hasOne<T, M>(
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

/// get result of one to one relationship query
Future<Map<String, M>> getHasOne<T, M>(dynamic q, List<Model<T>> list) async {
  if (q == null) return <String, M>{}; // coverage:ignore-line
  List<M> results = await q.get();

  Map<String, M> ret = <String, M>{};

  /// filter matched values with local id value
  for (M r in results) {
    Map<String, dynamic> map = (r as Model<M>).toMap(original: true);
    String ownerId = map['_owner_id'].toString();
    ret[ownerId] = r;
  }

  return ret;
}
