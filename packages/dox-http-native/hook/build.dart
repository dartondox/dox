// Ships the native library of dox_http_native as a code asset.
//
// Where the library comes from, first match wins:
// 1. The `lib_path` user define: a path to a ready library (for dev).
//    In the root pubspec.yaml of the app:
//      hooks:
//        user_defines:
//          dox_http_native:
//            lib_path: /path/to/libdox_http_native.so
// 2. A local build in `native/target/release` (for dev, same OS and CPU).
// 3. The ready-built library from the GitHub release, checked with sha256.
// 4. `cargo build` from source, when cargo is installed.
// When none works, no asset is added. Dox then logs a warning and uses
// dart:io instead. The build never fails because of this package.
import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:crypto/crypto.dart';
import 'package:hooks/hooks.dart';

const String _releases = 'https://github.com/dartondox/dox/releases/download';

/// sha256 of each release asset. Fill it from `SHA256SUMS` of the release
/// (see .github/workflows/native.yaml) before publishing to pub.dev.
/// These are from the release `dox_http_native-v3.0.0-alpha.3`.
const Map<String, String> _sha256 = <String, String>{
  'dox_http_native-linux-arm64.so':
      'c95eb643d3dbfe6f12b56b1d114c3c700769839f188cb7afa0afdc950f083f6e',
  'dox_http_native-linux-x64.so':
      '24ae2863a08fd3ff9ec03631c3627dac49f5c94bd2f33e6dbc24ad3ec539d51e',
  'dox_http_native-macos-arm64.dylib':
      'f8dba28cdf8a7a52fdd72465a9376c66d2ec1be60f3b0b25500cc4156623f228',
  'dox_http_native-macos-x64.dylib':
      '65fcc4eadf3e28ac08624d36bfdfec4c562e2f0cea268bea2edd350355dd091a',
  'dox_http_native-windows-x64.dll':
      '51b20d5fca8b8bca4a2c69adad692f67494a033e167d286154e29123fbf251a0',
};

void main(List<String> args) async {
  await build(args, (BuildInput input, BuildOutputBuilder output) async {
    if (!input.config.buildCodeAssets) return;
    CodeConfig code = input.config.code;
    OS os = code.targetOS;
    Architecture arch = code.targetArchitecture;
    String fileName = os.dylibFileName('dox_http_native');
    bool host = os == OS.current && arch == Architecture.current;
    Uri native = input.packageRoot.resolve('native/');

    Uri? lib =
        _given(input) ??
        (host ? _local(native, fileName) : null) ??
        await _download(input, os, arch, fileName) ??
        (host ? await _cargo(input, native, fileName, output) : null);

    if (lib == null) {
      stderr.writeln(
        'dox_http_native: no native library for ${os.name}-${arch.name}. '
        'Dox will use dart:io.',
      );
      return;
    }
    output.dependencies.add(lib);
    output.assets.code.add(
      CodeAsset(
        package: input.packageName,
        name: 'src/bindings.dart',
        linkMode: DynamicLoadingBundled(),
        file: lib,
      ),
    );
  });
}

Uri? _given(BuildInput input) {
  String? path = input.userDefines['lib_path'] as String?;
  if (path == null || path.isEmpty) return null;
  File file = File(path);
  if (!file.existsSync()) {
    throw StateError('dox_http_native: $path does not exist');
  }
  return file.absolute.uri;
}

Uri? _local(Uri native, String fileName) {
  Uri lib = native.resolve('target/release/$fileName');
  return File.fromUri(lib).existsSync() ? lib : null;
}

Future<Uri?> _download(
  BuildInput input,
  OS os,
  Architecture arch,
  String fileName,
) async {
  String ext = fileName.substring(fileName.lastIndexOf('.'));
  String asset = 'dox_http_native-${os.name}-${arch.name}$ext';
  String? hash = _sha256[asset];
  if (hash == null) return null; // no release for this platform (yet)

  // the release tag has the package version, eg. dox_http_native-v3.0.0
  String pubspec = File.fromUri(input.packageRoot.resolve('pubspec.yaml'))
      .readAsStringSync();
  String version = RegExp(
    r'^version:\s*(\S+)',
    multiLine: true,
  ).firstMatch(pubspec)![1]!;
  File file = File.fromUri(input.outputDirectoryShared.resolve(asset));
  if (file.existsSync() && _sha(file.readAsBytesSync()) == hash) {
    return file.uri;
  }
  HttpClient client = HttpClient();
  try {
    HttpClientRequest req = await client.getUrl(
      Uri.parse('$_releases/dox_http_native-v$version/$asset'),
    );
    HttpClientResponse res = await req.close();
    if (res.statusCode != 200) {
      stderr.writeln('dox_http_native: download $asset: ${res.statusCode}');
      return null;
    }
    List<int> bytes = <int>[
      for (List<int> chunk in await res.toList()) ...chunk,
    ];
    if (_sha(bytes) != hash) {
      stderr.writeln('dox_http_native: sha256 of $asset does not match');
      return null;
    }
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(bytes);
    return file.uri;
  } on IOException catch (error) {
    stderr.writeln('dox_http_native: download $asset failed: $error');
    return null;
  } finally {
    client.close(force: true);
  }
}

String _sha(List<int> bytes) => sha256.convert(bytes).toString();

Future<Uri?> _cargo(
  BuildInput input,
  Uri native,
  String fileName,
  BuildOutputBuilder output,
) async {
  String home =
      Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '';
  String cargo = 'cargo';
  File inHome = File('$home/.cargo/bin/cargo');
  if (home.isNotEmpty && inHome.existsSync()) cargo = inHome.path;

  Uri target = input.outputDirectoryShared.resolve('cargo/');
  try {
    ProcessResult result = await Process.run(cargo, <String>[
      'build',
      '--release',
      '--manifest-path',
      File.fromUri(native.resolve('Cargo.toml')).path,
      '--target-dir',
      Directory.fromUri(target).path,
    ]);
    if (result.exitCode != 0) {
      stderr.writeln('dox_http_native: cargo build failed\n${result.stderr}');
      return null;
    }
  } on ProcessException {
    return null; // no cargo
  }
  output.dependencies.add(native.resolve('Cargo.toml'));
  output.dependencies.add(native.resolve('src/lib.rs'));
  Uri lib = target.resolve('release/$fileName');
  return File.fromUri(lib).existsSync() ? lib : null;
}
