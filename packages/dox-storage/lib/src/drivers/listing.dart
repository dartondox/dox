import '../types.dart';

/// Shared listing helpers for drivers that list in memory (local, memory).
class Listing {
  const Listing();

  /// Turn a flat list of file keys into listing entries under [prefix].
  /// Non-recursive listings fold deeper keys into folders.
  List<DriveEntry> fromKeys(
    Iterable<String> keys,
    String prefix,
    bool recursive,
  ) {
    String start = prefix.isEmpty ? '' : '$prefix/';
    Set<String> folders = <String>{};
    List<DriveEntry> entries = <DriveEntry>[];
    for (String key in keys) {
      if (!key.startsWith(start)) {
        continue;
      }
      String rest = key.substring(start.length);
      int slash = rest.indexOf('/');
      if (recursive || slash == -1) {
        entries.add(DriveFile(key));
      } else if (folders.add(rest.substring(0, slash))) {
        entries.add(DriveDirectory('$start${rest.substring(0, slash)}'));
      }
    }
    return entries;
  }

  /// Sort entries by key and cut one page.
  /// The pagination token is the offset of the next page.
  ListResult paginate(List<DriveEntry> entries, ListOptions options) {
    entries.sort(_compareKeys);
    int? limit = options.limit;
    if (limit == null) {
      return ListResult(entries);
    }
    int offset = int.tryParse(options.paginationToken ?? '') ?? 0;
    int end = offset + limit;
    if (end >= entries.length) {
      return ListResult(entries.sublist(offset.clamp(0, entries.length)));
    }
    return ListResult(entries.sublist(offset, end), paginationToken: '$end');
  }

  static int _compareKeys(DriveEntry a, DriveEntry b) {
    return a.key.compareTo(b.key);
  }
}
