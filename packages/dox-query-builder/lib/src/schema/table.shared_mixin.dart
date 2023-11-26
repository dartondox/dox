import 'package:dox_query_builder/dox_query_builder.dart';

import '../utils/logger.dart';
import 'table.column.dart';

abstract class TableSharedMixin {
  final List<TableColumn> columns = <TableColumn>[];
  String tableName = '';
  bool debug = false;
  DBDriver get db;
  Logger get logger;
}
