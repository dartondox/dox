abstract class StorageDriverInterface {
  Future<String> put(String filePath, List<int> bytes, {String? extension});

  Future<List<int>?> get(String filepath);

  Future<bool> exists(String filepath);

  Future<dynamic> delete(String filepath);
}
