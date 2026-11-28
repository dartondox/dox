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

/// The prefix (like `p.`, or empty) to call the generated function [name]
/// of the part of [target] from [library], or null when [library] can
/// not see it: [target] is in another package, its file has no
/// `part '<file>.g.dart';` (so the function is not made), or no import
/// gives the name. An import or an export with `show` or `hide` gives the name only
/// when the name passes it. The generated function is not in the element
/// model yet, so the directives are read, not the names.
String? generatedPrefix(
  LibraryElement library,
  InterfaceElement target,
  String name,
) {
  LibraryElement home = target.library;
  if (!hasGeneratedPart(home)) return null;
  if (home == library) return '';
  if (_packageOf(home.uri) != _packageOf(library.uri)) return null;
  for (LibraryFragment fragment in library.fragments) {
    for (LibraryImport import in fragment.libraryImports) {
      LibraryElement? imported = import.importedLibrary;
      if (imported == null || !_passes(import.combinators, name)) continue;
      if (!_exports(imported, home, name, <LibraryElement>{})) continue;
      String? prefix = import.prefix?.element.name;
      return prefix == null ? '' : '$prefix.';
    }
  }
  return null;
}

/// `true` when [library] has the part `<file>.g.dart` of its own file,
/// where the generated code of dox_builder goes.
bool hasGeneratedPart(LibraryElement library) {
  String file = library.uri.pathSegments.lastOrNull ?? '';
  String part = '${file.replaceFirst(RegExp(r'\.dart$'), '')}.g.dart';
  for (PartInclude include in library.firstFragment.partIncludes) {
    DirectiveUri uri = include.uri;
    if (uri is DirectiveUriWithRelativeUriString &&
        uri.relativeUriString.split('/').last == part) {
      return true;
    }
  }
  return false;
}

/// `true` when [from] is [home], or exports [name] of [home]
bool _exports(
  LibraryElement from,
  LibraryElement home,
  String name,
  Set<LibraryElement> seen,
) {
  if (from == home) return true;
  if (!seen.add(from)) return false;
  for (LibraryFragment fragment in from.fragments) {
    for (LibraryExport export in fragment.libraryExports) {
      LibraryElement? exported = export.exportedLibrary;
      if (exported == null || !_passes(export.combinators, name)) continue;
      if (_exports(exported, home, name, seen)) return true;
    }
  }
  return false;
}

bool _passes(List<NamespaceCombinator> combinators, String name) {
  for (NamespaceCombinator combinator in combinators) {
    if (combinator is ShowElementCombinator &&
        !combinator.shownNames.contains(name)) {
      return false;
    }
    if (combinator is HideElementCombinator &&
        combinator.hiddenNames.contains(name)) {
      return false;
    }
  }
  return true;
}

String _packageOf(Uri uri) {
  return '${uri.scheme}:${uri.pathSegments.firstOrNull}';
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

/// `true` when the name [name] in the scope of [library] is a class of
/// dox_annotation. A newer generator asks this before it writes code that
/// uses the class, so the code still compiles with an older package.
bool seesAnnotationClass(LibraryFragment library, String name) {
  Element? found = library.scope.lookup(name).getter;
  return found is ClassElement &&
      found.library.uri.toString().startsWith('package:dox_annotation/');
}

/// `true` when [library] sees the classes of dox_annotation that the
/// `writeObject()` and the `$write` function of a DTO use.
bool seesDtoWriter(LibraryFragment library) {
  return seesAnnotationClass(library, 'JsonObjectWriter') &&
      seesAnnotationClass(library, 'JsonWriter') &&
      seesAnnotationClass(library, 'JsonRun');
}

/// `true` when [element] has the method [name]: its own, or one from a
/// class or a mixin above it.
bool hasMethod(InterfaceElement element, String name) {
  if (element.getMethod(name) != null) return true;
  for (InterfaceType above in element.allSupertypes) {
    if (above.element.getMethod(name) != null) return true;
  }
  return false;
}

final Set<String> _dartKeywords =
    ('abstract as assert async await break case catch class const continue covariant default deferred do dynamic else enum export extends extension external factory false final finally for get hide if implements import in interface is late library mixin new null of on operator part required rethrow return set show static super switch sync this throw true try typedef var void while with yield')
        .split(' ')
        .toSet();

/// The name of a generated local variable for [name], like a field. The
/// name stays as it is, unless it is in [taken], a Dart keyword, or a short
/// name with digits like `x0` (the generator uses those). Then it gets the
/// suffix `Value`, and a number when that is taken too. The result is added
/// to [taken].
String safeLocal(String name, Set<String> taken) {
  RegExp generated = RegExp(r'^[a-z]\d+$');
  String result = name;
  for (
    int n = 1;
    taken.contains(result) ||
        _dartKeywords.contains(result) ||
        generated.hasMatch(result);
    n++
  ) {
    result = n == 1 ? '${name}Value' : '${name}Value$n';
  }
  taken.add(result);
  return result;
}
