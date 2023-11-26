import 'package:dox_query_builder/dox_query_builder.dart';

/// belongs to relationship query
M? belongsTo<T, M>(
  List<Model<T>> list,
  Model<M> Function() model, {
  String? foreignKey,
  String? localKey,
  dynamic onQuery,
}) {
  if (list.isEmpty) return null;

  Model<T> foreign = list.first;
  Model<M> owner = model().debug(foreign.shouldDebug);
  localKey = localKey ?? owner.primaryKey;
  foreignKey = foreignKey ?? "${owner.tableName}_id";

  List<String> ids = list.map((dynamic i) {
    Map<String, dynamic> map = i.toMap();
    return map[foreignKey].toString();
  }).toList();

  owner
      .select(<String>[
        '${owner.tableName}.*',
        '${foreign.tableName}.${foreign.primaryKey} as _foreign_id'
      ])
      .leftJoin(
        foreign.tableName,
        '${foreign.tableName}.$foreignKey',
        '${owner.tableName}.$localKey',
      )
      .whereIn('${foreign.tableName}.$foreignKey', ids);

  if (onQuery != null) {
    owner = onQuery(owner);
  }
  return owner as M;
}

/// get result from belongs to relationship query
Future<Map<String, M>> getBelongsTo<T, M>(
  dynamic q,
  List<Model<T>> list,
) async {
  if (q == null) return <String, M>{}; // coverage:ignore-line
  List<M> results = await q.get();

  Map<String, M> ret = <String, M>{};

  /// filter matched values with local id value
  for (M r in results) {
    Map<String, dynamic> map = (r as Model<M>).toMap(original: true);
    ret[map['_foreign_id'].toString()] = r;
  }

  return ret;
}
