// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'owner.model.dart';

// **************************************************************************
// Generator: DoxModelBuilder
// **************************************************************************

// ignore_for_file: always_specify_types

class OwnerGenerator extends Model<Owner> {
  @override
  String get primaryKey => 'id';

  @override
  Map<String, dynamic> get timestampsColumn => <String, dynamic>{
    'created_at': null,
    'updated_at': null,
  };

  @override
  String get tableName => 'owners';

  int? get id => tempIdValue as int?;

  set id(int? val) => tempIdValue = val;

  Owner query() => Owner();

  @override
  List<String> get tableColumns => <String>['id', 'name'];

  @override
  List<String> get preloadList => <String>[];

  @override
  Map<String, Function> get relationsResultMatcher => <String, Function>{
    'pets': getPets,
    'firstPet': getFirstPet,
    'clubs': getClubs,
  };

  @override
  Map<String, Function> get relationsQueryMatcher => <String, Function>{
    'pets': queryPets,
    'firstPet': queryFirstPet,
    'clubs': queryClubs,
  };

  static Future<void> getPets(List<Model<Owner>> list) async {
    var result = await getHasMany<Owner, Pet>(queryPets(list), list);
    for (dynamic i in list) {
      if (result[i.tempIdValue.toString()] != null) {
        i.pets = result[i.tempIdValue.toString()]!;
      }
    }
  }

  static Pet? queryPets(List<Model<Owner>> list) {
    return hasMany<Owner, Pet>(list, () => Pet());
  }

  static Future<void> getFirstPet(List<Model<Owner>> list) async {
    var result = await getHasOne<Owner, Pet>(queryFirstPet(list), list);
    for (dynamic i in list) {
      if (result[i.tempIdValue.toString()] != null) {
        i.firstPet = result[i.tempIdValue.toString()]!;
      }
    }
  }

  static Pet? queryFirstPet(List<Model<Owner>> list) {
    return hasOne<Owner, Pet>(list, () => Pet());
  }

  static Future<void> getClubs(List<Model<Owner>> list) async {
    var result = await getManyToMany<Owner, Club>(queryClubs(list), list);
    for (dynamic i in list) {
      if (result[i.tempIdValue.toString()] != null) {
        i.clubs = result[i.tempIdValue.toString()]!;
      }
    }
  }

  static Club? queryClubs(List<Model<Owner>> list) {
    return manyToMany<Owner, Club>(list, () => Club());
  }

  @override
  Owner fromMap(Map<String, dynamic> m) => Owner()
    ..id = m['id'] as int?
    ..name = m['name'] as String?;

  @override
  Map<String, dynamic> convertToMap(dynamic i) {
    Owner instance = i as Owner;
    Map<String, dynamic> map = <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
    };

    List<String> preload = getPreload();
    if (preload.contains('pets')) {
      map['pets'] = toMap(instance.pets);
    }
    if (preload.contains('firstPet')) {
      map['first_pet'] = toMap(instance.firstPet);
    }
    if (preload.contains('clubs')) {
      map['clubs'] = toMap(instance.clubs);
    }

    return map;
  }
}

// ignore_for_file: always_specify_types

class PetGenerator extends Model<Pet> {
  @override
  String get primaryKey => 'id';

  @override
  Map<String, dynamic> get timestampsColumn => <String, dynamic>{
    'created_at': null,
    'updated_at': null,
  };

  @override
  String get tableName => 'pets';

  int? get id => tempIdValue as int?;

  set id(int? val) => tempIdValue = val;

  Pet query() => Pet();

  @override
  List<String> get tableColumns => <String>['id', 'name', 'owner_id'];

  @override
  List<String> get preloadList => <String>[];

  @override
  Map<String, Function> get relationsResultMatcher => <String, Function>{
    'owner': getOwner,
  };

  @override
  Map<String, Function> get relationsQueryMatcher => <String, Function>{
    'owner': queryOwner,
  };

  static Future<void> getOwner(List<Model<Pet>> list) async {
    var result = await getBelongsTo<Pet, Owner>(queryOwner(list), list);
    for (dynamic i in list) {
      if (result[i.tempIdValue.toString()] != null) {
        i.owner = result[i.tempIdValue.toString()]!;
      }
    }
  }

  static Owner? queryOwner(List<Model<Pet>> list) {
    return belongsTo<Pet, Owner>(list, () => Owner());
  }

  @override
  Pet fromMap(Map<String, dynamic> m) => Pet()
    ..id = m['id'] as int?
    ..name = m['name'] as String?
    ..ownerId = m['owner_id'] as int?;

  @override
  Map<String, dynamic> convertToMap(dynamic i) {
    Pet instance = i as Pet;
    Map<String, dynamic> map = <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'owner_id': instance.ownerId,
    };

    List<String> preload = getPreload();
    if (preload.contains('owner')) {
      map['owner'] = toMap(instance.owner);
    }

    return map;
  }
}

// ignore_for_file: always_specify_types

class ClubGenerator extends Model<Club> {
  @override
  String get primaryKey => 'id';

  @override
  Map<String, dynamic> get timestampsColumn => <String, dynamic>{
    'created_at': null,
    'updated_at': null,
  };

  @override
  String get tableName => 'clubs';

  int? get id => tempIdValue as int?;

  set id(int? val) => tempIdValue = val;

  Club query() => Club();

  @override
  List<String> get tableColumns => <String>['id', 'name'];

  @override
  List<String> get preloadList => <String>[];

  @override
  Map<String, Function> get relationsResultMatcher => <String, Function>{};

  @override
  Map<String, Function> get relationsQueryMatcher => <String, Function>{};

  @override
  Club fromMap(Map<String, dynamic> m) => Club()
    ..id = m['id'] as int?
    ..name = m['name'] as String?;

  @override
  Map<String, dynamic> convertToMap(dynamic i) {
    Club instance = i as Club;
    Map<String, dynamic> map = <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
    };

    return map;
  }
}
