DateTime now() {
  return DateTime.now().toUtc();
}

dynamic toMap(dynamic data) {
  if (data is List) {
    return data.map((dynamic e) => e.toJson()).toList();
  } else {
    return data?.toJson();
  }
}
