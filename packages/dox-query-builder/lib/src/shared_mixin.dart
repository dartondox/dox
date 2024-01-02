import 'package:dox_query_builder/dox_query_builder.dart';

import 'utils/helper.dart';
import 'utils/logger.dart';

abstract class SharedMixin<T> {
  QueryBuilder<T> get queryBuilder;
  QueryBuilderHelper<T> get helper;
  Logger get logger;
  DBDriver get dbDriver;
  Map<String, dynamic> get substitutionValues;
  String get selectQueryString;
  String primaryKey = 'id';
  bool shouldDebug = false;
  String tableName = '';
  bool isSoftDeletes = false;

  void addSubstitutionValues(String key, dynamic value);
  void resetSubstitutionValues();
}
