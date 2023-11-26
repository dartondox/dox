extension ToSnake on String {
  String toSnake() {
    StringBuffer result = StringBuffer();
    for (int letter in codeUnits) {
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
    return finalString;
  }
}
