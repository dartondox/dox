import 'package:dox_orm/dox_orm.dart';

part 'cast_item.model.g.dart';

enum Status { draft, live }

enum Level { low, mid, high }

class Money {
  final int cents;
  const Money(this.cents);
}

class MoneyCast extends Cast<Money> {
  const MoneyCast();

  @override
  Money? get(dynamic value) => value == null ? null : Money(value as int);

  @override
  dynamic set(Money? value) => value?.cents;
}

/// a model with column casts
@DoxModel(timestamps: false)
class CastItem extends CastItemGenerator {
  @Column(cast: JsonCast())
  Map<String, dynamic>? meta;

  @Column(cast: ListCast<String>())
  List<String>? tags;

  /// bool and enum fields get a cast without `cast:`
  @Column()
  bool? active;

  @Column()
  bool done = false;

  @Column()
  Status? status;

  @Column(cast: EnumCast<Level>(Level.values, byIndex: true))
  Level? level;

  @Column(cast: MoneyCast())
  Money? price;
}
