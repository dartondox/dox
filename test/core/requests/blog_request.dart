import 'package:dox_core/dox_core.dart';

class BlogRequest extends FormRequest {
  String? title;

  @override
  setUp() {
    title = input('title');
  }

  @override
  Map<String, String> rules() {
    return {
      'title': 'required',
    };
  }

  @override
  Map<String, String> messages() {
    return {
      'required': 'The {attribute} is missing',
    };
  }
}
