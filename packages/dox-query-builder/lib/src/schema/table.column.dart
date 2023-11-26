class TableColumn {
  final String name;
  final String? type;

  bool isNullable = false;
  dynamic defaultValue;
  bool isUnique = false;
  bool? shouldDrop = false;
  String? renameTo;

  TableColumn({
    required this.name,
    this.type,
    this.shouldDrop,
    this.renameTo,
  });

  TableColumn nullable([dynamic nullable]) {
    isNullable = (nullable is bool) ? nullable : true;
    return this;
  }

  TableColumn withDefault(dynamic val) {
    defaultValue = val;
    return this;
  }

  TableColumn unique() {
    isUnique = true;
    return this;
  }
}
