class Serializer<T> {
  List<T> _payload = [];

  bool _isSingular = true;

  Serializer(dynamic data) {
    if (data is List<T>) {
      _isSingular = false;
      _payload = data;
    }
    if (data is T) {
      _isSingular = true;
      _payload = [data];
    }
  }

  /// convert model into Map
  Map<String, dynamic> convert(T m) {
    return {};
  }

  toJson() {
    List<Map<String, dynamic>> ret = [];
    for (T p in _payload) {
      ret.add(convert(p));
    }
    if (_isSingular) {
      return ret.isNotEmpty ? ret.first : null;
    }
    return ret;
  }
}
