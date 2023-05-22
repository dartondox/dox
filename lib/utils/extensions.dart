extension MapExtensions on Map {
  Map<String, dynamic> removeParam(String keys) {
    dynamic value = this;
    List<String> parts = keys.split(".");
    List<String> k = parts.sublist(0, parts.length - 1);

    Map<String, dynamic> data = value;
    for (var i in k) {
      data = data[i];
    }
    data.remove(parts.last);
    return value;
  }

  dynamic getParam(String keys) {
    dynamic value = this;
    List<String> parts = keys.split(".");
    List<String> k = parts.sublist(0, parts.length - 1);

    var data = value;
    for (var i in k) {
      if (data[i] is List) {
        return data[i];
      }
      data = data[i];
    }
    return data[parts.last];
  }
}

extension JoinWithAnd on List {
  String joinWithAnd([String separator = ", "]) {
    List items = this;
    if (items.length <= 1) {
      return items.join();
    } else {
      final lastItem = items.removeLast();
      final joinedItems = items.join(separator);
      return '$joinedItems, and $lastItem';
    }
  }
}
