import 'package:dox_core/dox_core.dart';

class BlogRequest extends FormRequest {
  String? title;

  @override
  void setUp() {
    title = input('title');
  }

  @override
  Map<String, String> mapInputs() {
    return <String, String>{
      'foo': 'bar',
    };
  }

  @override
  Map<String, String> rules() {
    return <String, String>{
      'title': 'required',
    };
  }

  @override
  Map<String, String> messages() {
    return <String, String>{
      'required': 'The {field} is missing',
    };
  }
}
