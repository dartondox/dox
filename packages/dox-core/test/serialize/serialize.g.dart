// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'serialize.dart';

// **************************************************************************
// DoxSerializeGenerator
// **************************************************************************

// ignore_for_file: type=lint, unnecessary_null_comparison

/// The JSON writer of [Address]. Dox gets it from
/// `lib/generated/container.g.dart`.
const SerializeWriter $AddressWriter = _$AddressWriter();

class _$AddressWriter implements SerializeWriter {
  const _$AddressWriter();

  static final JsonRun _cityKey = JsonRun('{"city":');
  static final JsonRun _zipCodeKey = JsonRun(',"zip_code":');
  static final JsonRun _end = JsonRun('}');

  @override
  Type get type => Address;

  @override
  void writeObject(Object object, JsonWriter writer) =>
      $writeAddress(object as Address, writer);

  @override
  Object? toJsonValue(Object object) => $AddressToMap(object as Address);
}

/// Writes the JSON of [Address], as `toMap()` gives it.
void $writeAddress(Address dto, JsonWriter writer) {
  writer.run(_$AddressWriter._cityKey);
  writer.string(dto.city);
  writer.run(_$AddressWriter._zipCodeKey);
  writer.string(dto.zipCode);
  writer.run(_$AddressWriter._end);
}

/// The JSON of [Address] as a map.
Map<String, dynamic> $AddressToMap(Address dto) {
  return <String, dynamic>{'city': dto.city, 'zip_code': dto.zipCode};
}

/// The JSON writer of [ExtraUserData]. Dox gets it from
/// `lib/generated/container.g.dart`.
const SerializeWriter $ExtraUserDataWriter = _$ExtraUserDataWriter();

class _$ExtraUserDataWriter implements SerializeWriter {
  const _$ExtraUserDataWriter();

  static final JsonRun _loginCountKey = JsonRun('{"login_count":');
  static final JsonRun _lastSeenKey = JsonRun(',"seen":');
  static final JsonRun _rolesKey = JsonRun(',"roles":[');
  static final JsonRun _levelKey = JsonRun('],"level":');
  static final JsonRun _levelsKey = JsonRun(',"levels":[');
  static final JsonRun _homeKey = JsonRun('],"home":');
  static final JsonRun _workKey = JsonRun(',"work":');
  static final JsonRun _othersKey = JsonRun(',"others":[');
  static final JsonRun _countsKey = JsonRun('],"counts":');
  static final JsonRun _metaKey = JsonRun(',"meta":');
  static final JsonRun _ratioKey = JsonRun(',"ratio":');
  static final JsonRun _accountKey = JsonRun(',"account":');
  static final JsonRun _end = JsonRun('}');

  @override
  Type get type => ExtraUserData;

  @override
  void writeObject(Object object, JsonWriter writer) =>
      $writeExtraUserData(object as ExtraUserData, writer);

  @override
  Object? toJsonValue(Object object) =>
      $ExtraUserDataToMap(object as ExtraUserData);
}

/// Writes the JSON of [ExtraUserData], as `toMap()` gives it.
void $writeExtraUserData(ExtraUserData dto, JsonWriter writer) {
  writer.run(_$ExtraUserDataWriter._loginCountKey);
  writer.integer(dto.loginCount);
  writer.run(_$ExtraUserDataWriter._lastSeenKey);
  writer.dateTime(dto.lastSeen);
  writer.run(_$ExtraUserDataWriter._rolesKey);
  {
    List<String> roles = dto.roles;
    for (int i = 0; i < roles.length; i++) {
      if (i > 0) writer.run(JsonRun.comma);
      writer.string(roles[i]);
    }
  }
  writer.run(_$ExtraUserDataWriter._levelKey);
  writer.string(dto.level.name);
  writer.run(_$ExtraUserDataWriter._levelsKey);
  {
    List<Level> levels = dto.levels;
    for (int i = 0; i < levels.length; i++) {
      if (i > 0) writer.run(JsonRun.comma);
      writer.string(levels[i].name);
    }
  }
  writer.run(_$ExtraUserDataWriter._homeKey);
  {
    Address? $v = dto.home;
    if ($v != null && $v.runtimeType == Address) {
      $writeAddress($v, writer);
    } else {
      writer.value($v);
    }
  }
  writer.run(_$ExtraUserDataWriter._workKey);
  {
    Address? $v = dto.work;
    if ($v != null && $v.runtimeType == Address) {
      $writeAddress($v, writer);
    } else {
      writer.value($v);
    }
  }
  writer.run(_$ExtraUserDataWriter._othersKey);
  {
    List<Address> others = dto.others;
    for (int i = 0; i < others.length; i++) {
      if (i > 0) writer.run(JsonRun.comma);
      {
        Address? $v = others[i];
        if ($v != null && $v.runtimeType == Address) {
          $writeAddress($v, writer);
        } else {
          writer.value($v);
        }
      }
    }
  }
  writer.run(_$ExtraUserDataWriter._countsKey);
  writer.value(dto.counts);
  writer.run(_$ExtraUserDataWriter._metaKey);
  writer.value(dto.meta);
  writer.run(_$ExtraUserDataWriter._ratioKey);
  writer.value(dto.ratio);
  writer.run(_$ExtraUserDataWriter._accountKey);
  writer.value(dto.account);
  writer.run(_$ExtraUserDataWriter._end);
}

/// The JSON of [ExtraUserData] as a map.
Map<String, dynamic> $ExtraUserDataToMap(ExtraUserData dto) {
  DateTime? lastSeen = dto.lastSeen;
  Address home = dto.home;
  Address? work = dto.work;
  return <String, dynamic>{
    'login_count': dto.loginCount,
    'seen': lastSeen == null ? null : lastSeen.toIso8601String(),
    'roles': dto.roles,
    'level': dto.level.name,
    'levels': <dynamic>[for (Level x0 in dto.levels) x0.name],
    'home': (home.runtimeType == Address ? $AddressToMap(home) : home),
    'work': work == null
        ? null
        : (work.runtimeType == Address ? $AddressToMap(work) : work),
    'others': <dynamic>[
      for (Address x0 in dto.others)
        (x0.runtimeType == Address ? $AddressToMap(x0) : x0),
    ],
    'counts': dto.counts,
    'meta': dto.meta,
    'ratio': dto.ratio,
    'account': dto.account,
  };
}

/// The JSON writer of [UserInfo]. Dox gets it from
/// `lib/generated/container.g.dart`.
const SerializeWriter $UserInfoWriter = _$UserInfoWriter();

class _$UserInfoWriter implements SerializeWriter {
  const _$UserInfoWriter();

  static final JsonRun _dataKey = JsonRun('{"data":');
  static final JsonRun _extraKey = JsonRun(',"extra":');
  static final JsonRun _activeKey = JsonRun(',"active":');
  static final JsonRun _labelKey = JsonRun(',"label":');
  static final JsonRun _nameKey = JsonRun(',"name":');
  static final JsonRun _nickKey = JsonRun(',"nick":');
  static final JsonRun _tagsKey = JsonRun(',"tags":[');
  static final JsonRun _scoreKey = JsonRun('],"rating":{"score":');
  static final JsonRun _countKey = JsonRun(',"count":');
  static final JsonRun _halfKey = JsonRun(',"deep":{"half":');
  static final JsonRun _atKey = JsonRun(',"at":');
  static final JsonRun _postsKey = JsonRun('}},"posts":[');
  static final JsonRun _lastKey = JsonRun('],"last":');
  static final JsonRun _firstKey = JsonRun(',"first":');
  static final JsonRun _idKey = JsonRun(',"id":');
  static final JsonRun _end = JsonRun('}');
  static final JsonRun _listStart = JsonRun('[');
  static final JsonRun _listEnd = JsonRun(']');

  @override
  Type get type => UserInfo;

  @override
  void writeObject(Object object, JsonWriter writer) =>
      $writeUserInfo(object as UserInfo, writer);

  @override
  Object? toJsonValue(Object object) => (object as UserInfo).toJson();
}

/// Writes the JSON of [UserInfo], as `toJson()` gives it.
void $writeUserInfo(UserInfo serializer, JsonWriter writer) {
  List<User>? items = Serializer.listOf(serializer);
  if (items == null) {
    if (Serializer.hasItem(serializer)) {
      _$writeUserInfo$item(serializer, Serializer.itemOf(serializer), writer);
    } else {
      writer.value(null);
    }
    return;
  }
  writer.run(_$UserInfoWriter._listStart);
  for (int i = 0; i < items.length; i++) {
    if (i > 0) writer.run(JsonRun.comma);
    _$writeUserInfo$item(serializer, items[i], writer);
  }
  writer.run(_$UserInfoWriter._listEnd);
}

/// Writes the map of `convert()` of [UserInfo].
void _$writeUserInfo$item(UserInfo serializer, User m, JsonWriter writer) {
  DateTime base = serializer.now ?? DateTime.utc(2024);
  bool recent = m.createdAt.isAfter(base.subtract(const Duration(days: 2)));
  String label = m.score > 10 ? UserInfo.top : 'normal';
  writer.run(_$UserInfoWriter._dataKey);
  if (m.account case final $v?) {
    $v.writeJson(writer);
  } else {
    writer.value(null);
  }
  writer.run(_$UserInfoWriter._extraKey);
  {
    ExtraUserData? $v = ExtraUserData.of(m);
    if ($v != null && $v.runtimeType == ExtraUserData) {
      $writeExtraUserData($v, writer);
    } else {
      writer.value($v);
    }
  }
  writer.run(_$UserInfoWriter._activeKey);
  writer.boolean(recent);
  writer.run(_$UserInfoWriter._labelKey);
  writer.string(label);
  writer.run(_$UserInfoWriter._nameKey);
  writer.string('${serializer.prefix}${m.name}');
  writer.run(_$UserInfoWriter._nickKey);
  writer.string(m.nick ?? m.name);
  writer.run(_$UserInfoWriter._tagsKey);
  {
    List<String?> tagsValue = m.posts
        .expand((Post p) => p.tags)
        .map(serializer._tagName)
        .toList();
    for (int i = 0; i < tagsValue.length; i++) {
      if (i > 0) writer.run(JsonRun.comma);
      writer.string(tagsValue[i]);
    }
  }
  writer.run(_$UserInfoWriter._scoreKey);
  writer.integer(m.score);
  writer.run(_$UserInfoWriter._countKey);
  writer.integer(m.posts.length);
  writer.run(_$UserInfoWriter._halfKey);
  writer.value(m.score / 2);
  writer.run(_$UserInfoWriter._atKey);
  writer.dateTime(m.createdAt);
  writer.run(_$UserInfoWriter._postsKey);
  {
    List<Post> postsValue = m.posts;
    for (int i = 0; i < postsValue.length; i++) {
      if (i > 0) writer.run(JsonRun.comma);
      $writePostSerializer$item(postsValue[i], writer);
    }
  }
  writer.run(_$UserInfoWriter._lastKey);
  if (m.lastPost case final $v?) {
    $writePostSerializer$item($v, writer);
  } else {
    writer.value(null);
  }
  writer.run(_$UserInfoWriter._firstKey);
  writer.value(m.posts.isEmpty ? null : PostSerializer(m.posts.first));
  writer.run(_$UserInfoWriter._idKey);
  writer.integer(serializer.idOf(m));
  writer.run(_$UserInfoWriter._end);
}

/// The JSON writer of [PostSerializer]. Dox gets it from
/// `lib/generated/container.g.dart`.
const SerializeWriter $PostSerializerWriter = _$PostSerializerWriter();

class _$PostSerializerWriter implements SerializeWriter {
  const _$PostSerializerWriter();

  static final JsonRun _titleKey = JsonRun('{"title":');
  static final JsonRun _tagsKey = JsonRun(',"tags":[');
  static final JsonRun _labelsKey = JsonRun('],"labels":[');
  static final JsonRun _end = JsonRun(']}');
  static final JsonRun _listStart = JsonRun('[');
  static final JsonRun _listEnd = JsonRun(']');

  @override
  Type get type => PostSerializer;

  @override
  void writeObject(Object object, JsonWriter writer) =>
      $writePostSerializer(object as PostSerializer, writer);

  @override
  Object? toJsonValue(Object object) => (object as PostSerializer).toJson();
}

/// Writes the JSON of [PostSerializer], as `toJson()` gives it.
void $writePostSerializer(PostSerializer serializer, JsonWriter writer) {
  List<Post>? items = Serializer.listOf(serializer);
  if (items == null) {
    if (Serializer.hasItem(serializer)) {
      $writePostSerializer$item(Serializer.itemOf(serializer), writer);
    } else {
      writer.value(null);
    }
    return;
  }
  writer.run(_$PostSerializerWriter._listStart);
  for (int i = 0; i < items.length; i++) {
    if (i > 0) writer.run(JsonRun.comma);
    $writePostSerializer$item(items[i], writer);
  }
  writer.run(_$PostSerializerWriter._listEnd);
}

/// Writes the map of `convert()` of [PostSerializer].
void $writePostSerializer$item(Post m, JsonWriter writer) {
  writer.run(_$PostSerializerWriter._titleKey);
  writer.string(m.title);
  writer.run(_$PostSerializerWriter._tagsKey);
  {
    List<String?> tagsValue = <String?>[for (Tag t in m.tags) t.name];
    for (int i = 0; i < tagsValue.length; i++) {
      if (i > 0) writer.run(JsonRun.comma);
      writer.string(tagsValue[i]);
    }
  }
  writer.run(_$PostSerializerWriter._labelsKey);
  {
    List<Tag> labels = m.tags;
    for (int i = 0; i < labels.length; i++) {
      if (i > 0) writer.run(JsonRun.comma);
      $writeTagLabel$item(labels[i], writer);
    }
  }
  writer.run(_$PostSerializerWriter._end);
}

/// The JSON writer of [TagLabel]. Dox gets it from
/// `lib/generated/container.g.dart`.
const SerializeWriter $TagLabelWriter = _$TagLabelWriter();

class _$TagLabelWriter implements SerializeWriter {
  const _$TagLabelWriter();

  static final JsonRun _tagKey = JsonRun('{"tag":');
  static final JsonRun _end = JsonRun('}');
  static final JsonRun _listStart = JsonRun('[');
  static final JsonRun _listEnd = JsonRun(']');

  @override
  Type get type => TagLabel;

  @override
  void writeObject(Object object, JsonWriter writer) =>
      $writeTagLabel(object as TagLabel, writer);

  @override
  Object? toJsonValue(Object object) => (object as TagLabel).toJson();
}

/// Writes the JSON of [TagLabel], as `toJson()` gives it.
void $writeTagLabel(TagLabel serializer, JsonWriter writer) {
  List<Tag>? items = Serializer.listOf(serializer);
  if (items == null) {
    if (Serializer.hasItem(serializer)) {
      $writeTagLabel$item(Serializer.itemOf(serializer), writer);
    } else {
      writer.value(null);
    }
    return;
  }
  writer.run(_$TagLabelWriter._listStart);
  for (int i = 0; i < items.length; i++) {
    if (i > 0) writer.run(JsonRun.comma);
    $writeTagLabel$item(items[i], writer);
  }
  writer.run(_$TagLabelWriter._listEnd);
}

/// Writes the map of `convert()` of [TagLabel].
void $writeTagLabel$item(Tag m, JsonWriter writer) {
  writer.run(_$TagLabelWriter._tagKey);
  writer.string(m.name);
  writer.run(_$TagLabelWriter._end);
}

/// The JSON writer of [LabelOnly]. Dox gets it from
/// `lib/generated/container.g.dart`.
const SerializeWriter $LabelOnlyWriter = _$LabelOnlyWriter();

class _$LabelOnlyWriter implements SerializeWriter {
  const _$LabelOnlyWriter();

  static final JsonRun _labelKey = JsonRun('{"label":');
  static final JsonRun _end = JsonRun('}');
  static final JsonRun _listStart = JsonRun('[');
  static final JsonRun _listEnd = JsonRun(']');

  @override
  Type get type => LabelOnly;

  @override
  void writeObject(Object object, JsonWriter writer) =>
      $writeLabelOnly(object as LabelOnly, writer);

  @override
  Object? toJsonValue(Object object) => (object as LabelOnly).toJson();
}

/// Writes the JSON of [LabelOnly], as `toJson()` gives it.
void $writeLabelOnly(LabelOnly serializer, JsonWriter writer) {
  List<Tag>? items = Serializer.listOf(serializer);
  if (items == null) {
    if (Serializer.hasItem(serializer)) {
      _$writeLabelOnly$item(serializer, Serializer.itemOf(serializer), writer);
    } else {
      writer.value(null);
    }
    return;
  }
  writer.run(_$LabelOnlyWriter._listStart);
  for (int i = 0; i < items.length; i++) {
    if (i > 0) writer.run(JsonRun.comma);
    _$writeLabelOnly$item(serializer, items[i], writer);
  }
  writer.run(_$LabelOnlyWriter._listEnd);
}

/// Writes the map of `convert()` of [LabelOnly].
void _$writeLabelOnly$item(LabelOnly serializer, Tag m, JsonWriter writer) {
  writer.run(_$LabelOnlyWriter._labelKey);
  writer.string('${serializer.mark}${m.name}');
  writer.run(_$LabelOnlyWriter._end);
}

/// The JSON writer of [EmptySerializer]. Dox gets it from
/// `lib/generated/container.g.dart`.
const SerializeWriter $EmptySerializerWriter = _$EmptySerializerWriter();

class _$EmptySerializerWriter implements SerializeWriter {
  const _$EmptySerializerWriter();

  static final JsonRun _end = JsonRun('{}');
  static final JsonRun _listStart = JsonRun('[');
  static final JsonRun _listEnd = JsonRun(']');

  @override
  Type get type => EmptySerializer;

  @override
  void writeObject(Object object, JsonWriter writer) =>
      $writeEmptySerializer(object as EmptySerializer, writer);

  @override
  Object? toJsonValue(Object object) => (object as EmptySerializer).toJson();
}

/// Writes the JSON of [EmptySerializer], as `toJson()` gives it.
void $writeEmptySerializer(EmptySerializer serializer, JsonWriter writer) {
  List<Post>? items = Serializer.listOf(serializer);
  if (items == null) {
    if (Serializer.hasItem(serializer)) {
      $writeEmptySerializer$item(Serializer.itemOf(serializer), writer);
    } else {
      writer.value(null);
    }
    return;
  }
  writer.run(_$EmptySerializerWriter._listStart);
  for (int i = 0; i < items.length; i++) {
    if (i > 0) writer.run(JsonRun.comma);
    $writeEmptySerializer$item(items[i], writer);
  }
  writer.run(_$EmptySerializerWriter._listEnd);
}

/// Writes the map of `convert()` of [EmptySerializer].
void $writeEmptySerializer$item(Post m, JsonWriter writer) {
  writer.run(_$EmptySerializerWriter._end);
}

// WithIf: no JSON writer, a map in convert() has a collection if, for or spread.

// WithFor: no JSON writer, a map in convert() has a collection if, for or spread.

// WithSpread: no JSON writer, a map in convert() has a collection if, for or spread.

// WithKey: no JSON writer, a map in convert() has a key that is not a constant string: m.title.

// WithIfStatement: no JSON writer, convert() has an if statement. Only local variables can come before the return.

// WithMapVariable: no JSON writer, convert() does not return a map literal.

// OwnJson: no JSON writer, it has its own toJson().

/// The JSON writer of [TagNames]. Dox gets it from
/// `lib/generated/container.g.dart`.
const SerializeWriter $TagNamesWriter = _$TagNamesWriter();

class _$TagNamesWriter implements SerializeWriter {
  const _$TagNamesWriter();

  static final JsonRun _nKey = JsonRun('{"n":');
  static final JsonRun _end = JsonRun('}');
  static final JsonRun _listStart = JsonRun('[');
  static final JsonRun _listEnd = JsonRun(']');

  @override
  Type get type => TagNames;

  @override
  void writeObject(Object object, JsonWriter writer) =>
      $writeTagNames(object as TagNames, writer);

  @override
  Object? toJsonValue(Object object) => (object as TagNames).toJson();
}

/// Writes the JSON of [TagNames], as `toJson()` gives it.
void $writeTagNames(TagNames serializer, JsonWriter writer) {
  List<Tag>? items = Serializer.listOf(serializer);
  if (items == null) {
    if (Serializer.hasItem(serializer)) {
      _$writeTagNames$item(serializer, Serializer.itemOf(serializer), writer);
    } else {
      writer.value(null);
    }
    return;
  }
  writer.run(_$TagNamesWriter._listStart);
  for (int i = 0; i < items.length; i++) {
    if (i > 0) writer.run(JsonRun.comma);
    _$writeTagNames$item(serializer, items[i], writer);
  }
  writer.run(_$TagNamesWriter._listEnd);
}

/// Writes the map of `convert()` of [TagNames].
void _$writeTagNames$item(TagNames serializer, Tag m, JsonWriter writer) {
  writer.run(_$TagNamesWriter._nKey);
  writer.string(m.name);
  writer.run(_$TagNamesWriter._end);
}

/// The JSON writer of [PostTags]. Dox gets it from
/// `lib/generated/container.g.dart`.
const SerializeWriter $PostTagsWriter = _$PostTagsWriter();

class _$PostTagsWriter implements SerializeWriter {
  const _$PostTagsWriter();

  static final JsonRun _tagsKey = JsonRun('{"tags":');
  static final JsonRun _authorKey = JsonRun(',"author":');
  static final JsonRun _end = JsonRun('}');
  static final JsonRun _listStart = JsonRun('[');
  static final JsonRun _listEnd = JsonRun(']');

  @override
  Type get type => PostTags;

  @override
  void writeObject(Object object, JsonWriter writer) =>
      $writePostTags(object as PostTags, writer);

  @override
  Object? toJsonValue(Object object) => (object as PostTags).toJson();
}

/// Writes the JSON of [PostTags], as `toJson()` gives it.
void $writePostTags(PostTags serializer, JsonWriter writer) {
  List<Post>? items = Serializer.listOf(serializer);
  if (items == null) {
    if (Serializer.hasItem(serializer)) {
      $writePostTags$item(Serializer.itemOf(serializer), writer);
    } else {
      writer.value(null);
    }
    return;
  }
  writer.run(_$PostTagsWriter._listStart);
  for (int i = 0; i < items.length; i++) {
    if (i > 0) writer.run(JsonRun.comma);
    $writePostTags$item(items[i], writer);
  }
  writer.run(_$PostTagsWriter._listEnd);
}

/// Writes the map of `convert()` of [PostTags].
void $writePostTags$item(Post m, JsonWriter writer) {
  writer.run(_$PostTagsWriter._tagsKey);
  $writeTagNames(TagNames(m.tags.isEmpty ? null : m.tags.first), writer);
  writer.run(_$PostTagsWriter._authorKey);
  {
    Author? $v = m.title == 'special'
        ? SpecialAuthor('b', 'gold')
        : const Author('a');
    if ($v != null && $v.runtimeType == Author) {
      $writeAuthor($v, writer);
    } else {
      writer.value($v);
    }
  }
  writer.run(_$PostTagsWriter._end);
}

/// The JSON writer of [ParentS]. Dox gets it from
/// `lib/generated/container.g.dart`.
const SerializeWriter $ParentSWriter = _$ParentSWriter();

class _$ParentSWriter implements SerializeWriter {
  const _$ParentSWriter();

  static final JsonRun _parentKey = JsonRun('{"parent":');
  static final JsonRun _end = JsonRun('}');
  static final JsonRun _listStart = JsonRun('[');
  static final JsonRun _listEnd = JsonRun(']');

  @override
  Type get type => ParentS;

  @override
  void writeObject(Object object, JsonWriter writer) =>
      $writeParentS(object as ParentS, writer);

  @override
  Object? toJsonValue(Object object) => (object as ParentS).toJson();
}

/// Writes the JSON of [ParentS], as `toJson()` gives it.
void $writeParentS(ParentS serializer, JsonWriter writer) {
  List<Tag>? items = Serializer.listOf(serializer);
  if (items == null) {
    if (Serializer.hasItem(serializer)) {
      $writeParentS$item(Serializer.itemOf(serializer), writer);
    } else {
      writer.value(null);
    }
    return;
  }
  writer.run(_$ParentSWriter._listStart);
  for (int i = 0; i < items.length; i++) {
    if (i > 0) writer.run(JsonRun.comma);
    $writeParentS$item(items[i], writer);
  }
  writer.run(_$ParentSWriter._listEnd);
}

/// Writes the map of `convert()` of [ParentS].
void $writeParentS$item(Tag m, JsonWriter writer) {
  writer.run(_$ParentSWriter._parentKey);
  writer.string(m.name);
  writer.run(_$ParentSWriter._end);
}

// ChildIfS: no JSON writer, a map in convert() has a collection if, for or spread.

/// The JSON writer of [ChildFastS]. Dox gets it from
/// `lib/generated/container.g.dart`.
const SerializeWriter $ChildFastSWriter = _$ChildFastSWriter();

class _$ChildFastSWriter implements SerializeWriter {
  const _$ChildFastSWriter();

  static final JsonRun _fastKey = JsonRun('{"fast":');
  static final JsonRun _end = JsonRun('}');
  static final JsonRun _listStart = JsonRun('[');
  static final JsonRun _listEnd = JsonRun(']');

  @override
  Type get type => ChildFastS;

  @override
  void writeObject(Object object, JsonWriter writer) =>
      $writeChildFastS(object as ChildFastS, writer);

  @override
  Object? toJsonValue(Object object) => (object as ChildFastS).toJson();
}

/// Writes the JSON of [ChildFastS], as `toJson()` gives it.
void $writeChildFastS(ChildFastS serializer, JsonWriter writer) {
  List<Tag>? items = Serializer.listOf(serializer);
  if (items == null) {
    if (Serializer.hasItem(serializer)) {
      _$writeChildFastS$item(serializer, Serializer.itemOf(serializer), writer);
    } else {
      writer.value(null);
    }
    return;
  }
  writer.run(_$ChildFastSWriter._listStart);
  for (int i = 0; i < items.length; i++) {
    if (i > 0) writer.run(JsonRun.comma);
    _$writeChildFastS$item(serializer, items[i], writer);
  }
  writer.run(_$ChildFastSWriter._listEnd);
}

/// Writes the map of `convert()` of [ChildFastS].
void _$writeChildFastS$item(ChildFastS serializer, Tag m, JsonWriter writer) {
  writer.run(_$ChildFastSWriter._fastKey);
  writer.string(m.name);
  writer.run(_$ChildFastSWriter._end);
}

/// The JSON writer of [Author]. Dox gets it from
/// `lib/generated/container.g.dart`.
const SerializeWriter $AuthorWriter = _$AuthorWriter();

class _$AuthorWriter implements SerializeWriter {
  const _$AuthorWriter();

  static final JsonRun _nameKey = JsonRun('{"name":');
  static final JsonRun _end = JsonRun('}');

  @override
  Type get type => Author;

  @override
  void writeObject(Object object, JsonWriter writer) =>
      $writeAuthor(object as Author, writer);

  @override
  Object? toJsonValue(Object object) => $AuthorToMap(object as Author);
}

/// Writes the JSON of [Author], as `toMap()` gives it.
void $writeAuthor(Author dto, JsonWriter writer) {
  writer.run(_$AuthorWriter._nameKey);
  writer.string(dto.name);
  writer.run(_$AuthorWriter._end);
}

/// The JSON of [Author] as a map.
Map<String, dynamic> $AuthorToMap(Author dto) {
  return <String, dynamic>{'name': dto.name};
}
