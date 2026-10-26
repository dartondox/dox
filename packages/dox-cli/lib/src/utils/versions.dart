/// The newest of [versions] with the same major version as [current].
/// Pre-releases count. Null when there is none.
/// ```
/// newestOfMajor(['2.0.1', '3.0.0-alpha.4'], '3.0.0-alpha.2'); // 3.0.0-alpha.4
/// ```
String? newestOfMajor(Iterable<String> versions, String current) {
  String major = current.split('.').first;
  List<String> same = <String>[
    for (String v in versions)
      if (v.startsWith('$major.')) v,
  ];
  if (same.isEmpty) return null;
  same.sort(compareVersions);
  return same.last;
}

/// Sorts `3.0.0-alpha.2 < 3.0.0-alpha.10 < 3.0.0-beta.1 < 3.0.0-rc.1
/// < 3.0.0 < 3.1.0`.
int compareVersions(String a, String b) {
  List<int> ka = _key(a), kb = _key(b);
  for (int i = 0; i < ka.length && i < kb.length; i++) {
    if (ka[i] != kb[i]) return ka[i].compareTo(kb[i]);
  }
  return ka.length.compareTo(kb.length);
}

/// The order of pre-release labels. A label not in the list ranks first.
const List<String> _labels = <String>['alpha', 'beta', 'rc'];

List<int> _key(String v) {
  List<String> parts = v.split('-');
  List<int> nums = parts.first.split('.').map(int.parse).toList();
  // a stable version ranks above every pre-release of the same base
  if (parts.length == 1) return [...nums, 1, 0, 0];
  // the label first (alpha < beta < rc), then its number
  String label = parts[1].split('.').first;
  Match? n = RegExp(r'\d+$').firstMatch(parts[1]);
  return [
    ...nums,
    0,
    _labels.indexOf(label) + 1,
    n == null ? 0 : int.parse(n.group(0)!),
  ];
}
