import 'package:dox_orm/dox_orm.dart';

part 'tag.model.g.dart';

@DoxModel()
class Tag extends TagGenerator {
  @Column()
  String? title;
}
