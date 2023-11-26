import 'dart:convert';

import 'package:dox_query_builder/dox_query_builder.dart';

// coverage:ignore-file
class ConsoleQueryPrinter implements QueryPrinter {
  Function(String)? filter;

  ConsoleQueryPrinter({
    this.filter,
  });

  @override
  void log(String query, List<String> params) {
    Map<String, dynamic> payload = <String, dynamic>{
      'timestamp': DateTime.now().toIso8601String(),
      'level': 'INFO',
      'message': query,
      'payload': <String, dynamic>{
        'query': query,
        'params': params,
      }
    };
    String stringToPrint = jsonEncode(payload);
    if (filter != null) {
      stringToPrint = filter!(stringToPrint);
    }
    print(stringToPrint);
  }
}
