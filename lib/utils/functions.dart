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
}
