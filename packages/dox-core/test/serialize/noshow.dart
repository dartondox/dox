// The file sees only Serializer and Serialize, so it gets no fast code.
import 'package:dox_core/dox_core.dart' show Serialize, Serializer;

part 'noshow.g.dart';

class Thing {
  Thing(this.name);

  final String name;
}

@Serialize()
class ThingSer extends Serializer<Thing> {
  ThingSer(super.data);

  @override
  Map<String, dynamic> convert(Thing m) => <String, dynamic>{'n': m.name};
}

@Serialize()
class PlainB {
  final int id;

  const PlainB(this.id);
}
