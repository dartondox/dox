import 'dart:io';

extension FileName on File {
  String get name {
    Uri uri = Platform.script.resolve(path);
    return uri.pathSegments.last.split('.').first;
  }

  String get ext {
    Uri uri = Platform.script.resolve(path);
    return uri.pathSegments.last.split('.').last.toLowerCase();
  }

  bool get isUp {
    Uri uri = Platform.script.resolve(path);
    return uri.pathSegments.last.toLowerCase().contains('.up.');
  }

  bool get isDown {
    Uri uri = Platform.script.resolve(path);
    return uri.pathSegments.last.toLowerCase().contains('.down.');
  }
}
