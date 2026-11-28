class Serializer<T> {
  /// the one item, when [_one] is true
  T? _item;

  /// the items, when the serializer was made with a list
  List<T>? _list;

  /// true when there is one item in [_item]
  bool _one = false;

  Serializer(dynamic data) {
    // a value that is a T is one item, even when it is a list too
    if (data is T) {
      _item = data;
      _one = true;
    } else if (data is List<T>) {
      _list = data;
    }
  }

  /// The items of [serializer] when it was made with a list, so its JSON
  /// is an array. Else null. For the JSON writer that `@Serialize()`
  /// makes.
  static List<T>? listOf<T>(Serializer<T> serializer) {
    return serializer._list;
  }

  /// `true` when [serializer] was made with one item (not a list and not
  /// `null`). For the JSON writer that `@Serialize()` makes.
  static bool hasItem(Serializer<Object?> serializer) {
    return serializer._one;
  }

  /// The one item of [serializer]. Only call it when [hasItem] is true.
  /// For the JSON writer that `@Serialize()` makes.
  static T itemOf<T>(Serializer<T> serializer) {
    return serializer._item as T;
  }

  /// coverage:ignore-start
  /// convert model into Map
  Map<String, dynamic> convert(T m) {
    return <String, dynamic>{};
  }

  /// coverage:ignore-end

  dynamic toJson() {
    List<T>? list = _list;
    if (list != null) {
      List<Map<String, dynamic>> ret = <Map<String, dynamic>>[];
      for (T p in list) {
        ret.add(convert(p));
      }
      return ret;
    }
    return _one ? convert(_item as T) : null;
  }
}
