import 'package:dox_core/http/request/form_input.dart';

import 'src/fuzz_target.dart';

/// An urlencoded body, read like `req.body`.
class FormBodyTarget extends FuzzTarget {
  const FormBodyTarget();

  @override
  String get name => 'form_body';

  @override
  String get library => 'package:dox_core/http/request/form_input.dart';

  @override
  List<String> get seeds => const <String>[
    'a=1&b=2',
    'tags[]=a&tags[]=b',
    'items[0][name]=x&items[1][name]=y',
    'address[city]=x&a=1&a=2',
    'a%20b=c%2Fd&k[3]=z',
  ];

  /// the same steps as `HttpBody._urlEncoded`
  @override
  void check(String input) {
    Map<String, dynamic> flat = <String, dynamic>{};
    try {
      flat = Uri.splitQueryString(input);
    } catch (error) {
      /// bad percent encoding: an empty body
    }
    const FormInput form = FormInput();
    noNull(form.nested(flat, () => form.pairs(input)));
  }
}

Future<void> main(List<String> args) => const FormBodyTarget().run(args);
