import 'package:dox_core/dox_core.dart';

class Blog {
  String title = 'hello';
}

class BlogSerializer extends Serializer<Blog> {
  BlogSerializer(super.data);

  /// convert model into Map
  @override
  Map<String, dynamic> convert(Blog m) {
    return <String, String>{
      'title': m.title,
    };
  }
}
