import 'package:dox_core/http/request/form_input.dart';

import 'src/fuzz_target.dart';

/// A query string, read like `req.query` and a DTO.
class FormQueryTarget extends FuzzTarget {
  const FormQueryTarget();

  @override
  String get name => 'form_query';

  @override
  String get library => 'package:dox_core/http/request/form_input.dart';

  @override
  List<String> get seeds => const <String>[
    'a=1&b=2',
    'tags=a&tags=b',
    'tags[]=a&tags[]=b',
    'items[0][name]=x&items[1][name]=y',
    'a%20b=c%2Fd&k[3]=z',
  ];

  @override
  void check(String input) {
    /// the server refuses a request line that is not a URI
    Uri? uri = Uri.tryParse('http://localhost/?$input');
    if (uri == null) return;
    Map<String, List<String>> all;
    try {
      all = uri.queryParametersAll;
    } on FormatException {
      return;
    } on ArgumentError {
      return;
    }
    if (all.isEmpty) return;
    noNull(const FormInput().query(uri));
  }
}

Future<void> main(List<String> args) => const FormQueryTarget().run(args);
