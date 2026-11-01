import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';

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
    // only letters have an upper case: digits and `_` stay as they are
    if (char != char.toLowerCase() && i > 0) {
      snakeCase += '_'; // Add an underscore if it's uppercase and not the first character
    }
    snakeCase += char.toLowerCase(); // Convert the character to lowercase and add it to the result
  }

  return snakeCase.replaceAll(RegExp(r'_+'), '_');
}

String ucFirst(String str) {
  return str.substring(0, 1).toUpperCase() + str.substring(1);
}

String lcFirst(String? str) {
  if (str == null) {
    return '';
  }
  return str.substring(0, 1).toLowerCase() + str.substring(1);
}

/// [type] as code in [library]. A type that [library] imports with a
/// prefix gets it, like `o.Role` for `import 'other.dart' as o;`.
/// Type arguments get their prefix too: `List<o.Role>`.
String typeCode(DartType type, LibraryElement? library) {
  String question = type.nullabilitySuffix == NullabilitySuffix.question
      ? '?'
      : '';
  InstantiatedTypeAliasElement? alias = type.alias;
  if (alias != null) {
    return '${prefixOf(alias.element, library)}${alias.element.displayName}'
        '${_typeArgs(alias.typeArguments, library)}$question';
  }
  if (type is InterfaceType) {
    return '${prefixOf(type.element, library)}${type.element.displayName}'
        '${_typeArgs(type.typeArguments, library)}$question';
  }
  // ponytail: function and record types are written without prefixes.
  // Add them here when a model or DTO needs one.
  return type.getDisplayString();
}

String _typeArgs(List<DartType> args, LibraryElement? library) {
  if (args.isEmpty) return '';
  List<String> codes = <String>[for (DartType t in args) typeCode(t, library)];
  return '<${codes.join(', ')}>';
}

/// The import prefix of [element] in [library], like `o.`, or empty.
/// It is empty when the element is in [library] or is imported without a
/// prefix.
String prefixOf(Element element, LibraryElement? library) {
  String? name = element.name;
  if (library == null || name == null || element.library == library) {
    return '';
  }
  String? prefix;
  for (LibraryFragment fragment in library.fragments) {
    for (LibraryImport import in fragment.libraryImports) {
      // definedNames2 has the names without the prefix, show and hide applied
      if (import.namespace.definedNames2[name] != element) continue;
      String? found = import.prefix?.element.name;
      if (found == null) return '';
      prefix ??= found;
    }
  }
  return prefix == null ? '' : '$prefix.';
}

/// A quick check of the text of a Dart file, before it is resolved
/// (resolving is slow). True when the text has one of [words] (any case),
/// or a `part` directive (a part file can hold the code).
bool mayHave(String text, List<String> words) {
  String lower = text.toLowerCase();
  if (lower.contains('part ')) return true;
  for (String word in words) {
    if (lower.contains(word)) return true;
  }
  return false;
}

/// True for files that a builder made (`.g.dart`, like the files in
/// `lib/generated/`): the aggregate builders skip them.
bool isGenerated(AssetId id) {
  return id.path.endsWith('.g.dart');
}
