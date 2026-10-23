import 'package:dox_orm/dox_orm.dart';

part 'owner.model.g.dart';

/// models with plural table names and no keys set on the relations.
/// The default keys use the model name: owner_id, club_id and the
/// pivot table club_owner.
@DoxModel(table: 'owners', timestamps: false)
class Owner extends OwnerGenerator {
  @Column()
  String? name;

  @HasMany(Pet)
  List<Pet> pets = <Pet>[];

  @HasOne(Pet)
  Pet? firstPet;

  @ManyToMany(Club)
  List<Club> clubs = <Club>[];
}

@DoxModel(table: 'pets', timestamps: false)
class Pet extends PetGenerator {
  @Column()
  String? name;

  @Column()
  int? ownerId;

  @BelongsTo(Owner)
  Owner? owner;
}

@DoxModel(table: 'clubs', timestamps: false)
class Club extends ClubGenerator {
  @Column()
  String? name;
}
