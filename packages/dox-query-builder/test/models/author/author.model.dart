import 'package:dox_query_builder/dox_query_builder.dart';

import '../book/book.model.dart';
import '../tag/tag.model.dart';

part 'author.model.g.dart';

/// relations use `code` as local key, not the primary key
@DoxModel()
class Author extends AuthorGenerator {
  @Column()
  String? code;

  @HasMany(Book, localKey: 'code', foreignKey: 'author_code')
  List<Book> books = <Book>[];

  @HasOne(Book, localKey: 'code', foreignKey: 'author_code')
  Book? book;

  @ManyToMany(
    Tag,
    localKey: 'code',
    pivotForeignKey: 'author_code',
    pivotTable: 'author_tag',
  )
  List<Tag> tags = <Tag>[];
}
