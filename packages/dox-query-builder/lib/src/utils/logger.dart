import 'package:dox_query_builder/dox_query_builder.dart';

// coverage:ignore-file
class Logger {
  void log(String query, [dynamic params]) {
    query = query.replaceAll(RegExp(r'@\w+'), '?');
    params = _parseParams(params);
    QueryPrinter printer = SqlQueryBuilder().printer;
    printer.log(query, params);
  }

  List<String> _parseParams(dynamic params) {
    List<String> list = <String>[];
    if (params != null && (params as Map<String, dynamic>).isNotEmpty) {
      params.forEach((String key, dynamic value) {
        list.add(value.toString());
      });
    }
    return list;
  }

  /// log the text using info color (lightblue)
  /// ```
  /// Logger.info('using dox is fun');
  /// ```
  static void info(dynamic text) {
    print('\x1B[36m$text\x1B[0m');
  }

  /// log the text using warn color (yellow)
  /// ```
  /// Logger.warn('careful!');
  ///
  static void warn(dynamic text) {
    print('\x1B[34m$text\x1B[0m');
  }

  /// log the text using success color (green)
  /// ```
  /// Logger.success('success');
  ///
  static void success(dynamic text) {
    print('\x1B[32m$text\x1B[0m');
  }

  /// log the text using danger color (red)
  /// ```
  /// Logger.danger('failed');
  ///
  static void danger(dynamic text) {
    print('\x1B[31m$text\x1B[0m');
  }
}
