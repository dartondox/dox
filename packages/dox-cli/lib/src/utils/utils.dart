import 'dart:io';

String pascalToSnake(String input) {
  final result = StringBuffer();
  for (final letter in input.codeUnits) {
    if (letter >= 65 && letter <= 90) {
      // Check if uppercase ASCII
      if (result.isNotEmpty) {
        // Add underscore if not first letter
        result.write('_');
      }
      result.write(String.fromCharCode(letter + 32)); // Add lowercase ASCII
    } else {
      result.write(String.fromCharCode(letter)); // Add original character
    }
  }
  String finalString = result.toString().replaceAll(RegExp('_+'), '_');
  finalString = finalString.endsWith('_')
      ? finalString.substring(0, finalString.length - 1)
      : finalString;
  return finalString;
}

String snakeToPascal(String input) {
  final parts = input.split('_');
  final result = StringBuffer();
  for (final part in parts) {
    if (part.isNotEmpty) {
      result.write('${part[0].toUpperCase()}${part.substring(1)}');
    }
  }
  return result.toString().isEmpty ? input : result.toString();
}

String toPascalWithFirstLetterLowerCase(String input) {
  String pascalString = snakeToPascal(input);
  return '${pascalString[0].toLowerCase()}${pascalString.substring(1)}';
}

Map<String, String> loadEnv() {
  Map<String, String> data = {};
  final file = File('${Directory.current.path}/.env');
  final contents = file.readAsStringSync();
  List list = contents.split('\n');
  for (var d in list) {
    List keyValue = d.toString().split('=');
    if (keyValue[0].toString().isNotEmpty) {
      data[keyValue[0].toString().trim()] = keyValue[1].toString().trim();
    }
  }
  return data;
}

String parseName(name) {
  DateTime now = DateTime.now();
  String uuid =
      '${now.year}_${_formatNumber(now.month)}_${_formatNumber(now.day)}_${_formatNumber(now.hour)}${_formatNumber(now.minute)}${_formatNumber(now.second)}${now.microsecond}';

  return "${uuid}_$name".replaceAll(RegExp(r'[^\w]'), "");
}

String _formatNumber(int number) {
  return number.toString().padLeft(2, '0');
}

String fileGetContents(path) {
  return File(path).readAsStringSync();
}
