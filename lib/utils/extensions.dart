extension MapExtensions on Map {
  /// remove parameter from map with dot
  /// ```
  /// map.removeParam('user.info');
  /// ```
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

  /// get parameter from map with dot
  /// ```
  /// map.getParam('user.info');
  /// ``
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
  /// jon list<String> with separator and the last item with 'and' or 'or'
  /// ```
  /// list.joinWithAnd();
  /// list.joinWithAnd(',', 'and');
  /// ```
  String joinWithAnd([String separator = ", ", String lastJoinText = 'and']) {
    List items = this;
    if (items.length <= 1) {
      return items.join();
    } else {
      final lastItem = items.removeLast();
      final joinedItems = items.join(separator);
      return '$joinedItems, $lastJoinText $lastItem';
    }
  }
}
