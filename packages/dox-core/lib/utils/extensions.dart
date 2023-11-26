extension MapExtensions on Map<dynamic, dynamic> {
  /// remove parameter from map with dot
  /// ```
  /// map.removeParam('user.info');
  /// ```
  Map<String, dynamic> removeParam(String keys) {
    dynamic value = this;
    List<String> parts = keys.split('.');
    List<String> k = parts.sublist(0, parts.length - 1);

    Map<String, dynamic> data = value;
    for (String i in k) {
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
    List<String> parts = keys.split('.');
    List<String> k = parts.sublist(0, parts.length - 1);

    Map<dynamic, dynamic> data = value;
    for (String i in k) {
      if (data[i] is List) {
        return data[i];
      }
      data = data[i];
    }
    return data[parts.last];
  }
}

extension JoinWithAnd on List<String> {
  /// jon list<String> with separator and the last item with 'and' or 'or'
  /// ```
  /// list.joinWithAnd();
  /// list.joinWithAnd(',', 'and');
  /// ```
  String joinWithAnd([String separator = ', ', String lastJoinText = 'and']) {
    List<dynamic> items = this;
    if (items.length <= 1) {
      return items.join();
    } else {
      String lastItem = items.removeLast();
      String joinedItems = items.join(separator);
      return '$joinedItems, $lastJoinText $lastItem';
    }
  }
}
