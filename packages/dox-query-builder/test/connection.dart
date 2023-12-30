import 'dart:io';

import 'package:dox_query_builder/dox_query_builder.dart';

import 'mysql.dart';
import 'postgres.dart';

Future<void> initQueryBuilder() async {
  SqlQueryBuilder.initialize(
    database: await poolConnection(),
    driver: getDriver(),
  );
}

Future<dynamic> poolConnection() {
  if (Platform.environment['DRIVER'] == 'postgres') {
    return postgresConnection();
  } else {
    return mysqlConnection();
  }
}

Driver getDriver() {
  if (Platform.environment['DRIVER'] == 'postgres') {
    return Driver.postgres;
  } else {
    return Driver.mysql;
  }
}
