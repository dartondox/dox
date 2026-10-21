/// Tiny reader for the few flat S3 XML responses we need.
///
/// ponytail: regex over known flat tags, not a real XML parser. S3 responses
/// are machine-made and flat, so this holds. Swap in `package:xml` if a
/// response with nested same-name tags is ever needed.
class S3Xml {
  const S3Xml();

  /// Inner text of every `<tag>...</tag>`, in order. Not decoded.
  List<String> all(String xml, String tag) {
    RegExp pattern = RegExp('<$tag>(.*?)</$tag>', dotAll: true);
    List<String> found = <String>[];
    for (RegExpMatch match in pattern.allMatches(xml)) {
      found.add(match.group(1)!);
    }
    return found;
  }

  /// Decoded text of the first `<tag>`, or null.
  String? first(String xml, String tag) {
    List<String> found = all(xml, tag);
    return found.isEmpty ? null : decode(found.first);
  }

  /// Decode XML entities.
  String decode(String text) {
    return text.replaceAllMapped(
      RegExp(r'&(#x[0-9a-fA-F]+|#[0-9]+|amp|lt|gt|quot|apos);'),
      _entity,
    );
  }

  /// Escape text for an XML body.
  String escape(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  static String _entity(Match match) {
    String name = match.group(1)!;
    switch (name) {
      case 'amp':
        return '&';
      case 'lt':
        return '<';
      case 'gt':
        return '>';
      case 'quot':
        return '"';
      case 'apos':
        return "'";
    }
    if (name.startsWith('#x')) {
      return String.fromCharCode(int.parse(name.substring(2), radix: 16));
    }
    return String.fromCharCode(int.parse(name.substring(1)));
  }
}
