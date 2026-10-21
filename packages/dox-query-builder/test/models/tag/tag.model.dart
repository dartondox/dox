import 'package:dox_query_builder/dox_query_builder.dart';

part 'tag.model.g.dart';

@DoxModel()
class Tag extends TagGenerator {
  @Column()
  String? title;
}
