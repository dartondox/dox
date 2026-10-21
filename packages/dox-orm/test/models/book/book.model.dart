import 'package:dox_orm/dox_orm.dart';

part 'book.model.g.dart';

@DoxModel()
class Book extends BookGenerator {
  @Column()
  String? title;

  @Column(name: 'author_code')
  String? authorCode;
}
