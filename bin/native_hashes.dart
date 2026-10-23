// Fills the `_sha256` map of a native package build hook from a GitHub
// release. Run it after the release workflow (.github/workflows/native.yaml)
// made the release, and before you publish the package.
//
//   dart run bin/native_hashes.dart dox_postgres_native-v3.0.0-alpha.5
//
// It downloads `SHA256SUMS` of the release and writes the hashes into
// packages/<dox-postgres-native>/hook/build.dart.
import 'dart:convert';
import 'dart:io';

const String _releases = 'https://github.com/dartondox/dox/releases/download';

Future<void> main(List<String> args) async {
  RegExpMatch? tag = args.length == 1
      ? RegExp(r'^(dox_[a-z_]+_native)-v\S+$').firstMatch(args.first)
      : null;
  if (tag == null) {
    stderr.writeln(
      'usage: dart run bin/native_hashes.dart <package>-v<version>',
    );
    exit(64);
  }
  String package = tag[1]!;
  File hook = File('packages/${package.replaceAll('_', '-')}/hook/build.dart');
  if (!hook.existsSync()) {
    stderr.writeln('${hook.path} not found. Run it from the repo root.');
    exit(66);
  }

  HttpClient client = HttpClient();
  String sums;
  try {
    Uri url = Uri.parse('$_releases/${args.first}/SHA256SUMS');
    HttpClientResponse res = await (await client.getUrl(url)).close();
    sums = await res.transform(utf8.decoder).join();
    if (res.statusCode != 200) {
      stderr.writeln('download $url: ${res.statusCode}');
      exit(69);
    }
  } finally {
    client.close(force: true);
  }

  // each line: `<sha256>  <asset name>`
  List<String> entries = <String>[];
  for (String line in LineSplitter.split(sums)) {
    List<String> parts = line.trim().split(RegExp(r'\s+\*?'));
    if (parts.length == 2 && parts[1].startsWith('$package-')) {
      entries.add("  '${parts[1]}':\n      '${parts[0]}',\n");
    }
  }
  if (entries.isEmpty) {
    stderr.writeln('no $package files in SHA256SUMS');
    exit(65);
  }
  entries.sort();

  String source = hook.readAsStringSync();
  RegExp map = RegExp(
    r'const Map<String, String> _sha256 = <String, String>\{[^}]*\};',
  );
  if (!map.hasMatch(source)) {
    stderr.writeln('no `_sha256` map in ${hook.path}');
    exit(65);
  }
  hook.writeAsStringSync(
    source.replaceFirst(
      map,
      'const Map<String, String> _sha256 = <String, String>{\n'
      '${entries.join()}};',
    ),
  );
  stdout.writeln('${hook.path}: ${entries.length} hashes from ${args.first}');
}
