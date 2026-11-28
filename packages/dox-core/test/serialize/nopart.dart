import 'package:dox_core/dox_core.dart';

/// `@Serialize()` classes in a file with no part: no fast writer.
class Item {
  Item(this.name);

  final String name;
}

@Serialize()
class ItemSer extends Serializer<Item> {
  ItemSer(super.data);

  @override
  Map<String, dynamic> convert(Item m) => <String, dynamic>{'n': m.name};
}

@Serialize()
class PlainNoPart {
  final int id;

  const PlainNoPart(this.id);

  Map<String, dynamic> toJson() => <String, dynamic>{'id': id};
}
