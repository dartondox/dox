import 'package:dox_query_builder/dox_query_builder.dart';

part 'book.model.g.dart';

@DoxModel()
class Book extends BookGenerator {
  @Column()
  String? title;

  @Column(name: 'author_code')
  String? authorCode;
}
