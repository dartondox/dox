String toCamelCase(String snakeCase) {
  List<String> words = snakeCase.split('_');
  String camelCase = words[0]; // Add the first word as it is

  for (int i = 1; i < words.length; i++) {
    String word = words[i];
    String capitalizedWord =
        word[0].toUpperCase() + word.substring(1).toLowerCase();
    camelCase += capitalizedWord;
  }
  return camelCase;
}

String toSnakeCase(String input) {
  String snakeCase = '';

  for (int i = 0; i < input.length; i++) {
    String char = input[i];
    // Check if the current character is uppercase
    if (char == char.toUpperCase() && i > 0) {
      snakeCase +=
          '_'; // Add an underscore if it's uppercase and not the first character
    }
    snakeCase += char
        .toLowerCase(); // Convert the character to lowercase and add it to the result
  }

  return snakeCase.replaceAll(RegExp(r'_+'), '_');
}

ucFirst(String str) {
  return str.substring(0, 1).toUpperCase() + str.substring(1);
}

lcFirst(String? str) {
  if (str == null) {
    return '';
  }
  return str.substring(0, 1).toLowerCase() + str.substring(1);
}
