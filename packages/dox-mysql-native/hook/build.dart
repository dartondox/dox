// Ships the native library of dox_mysql_native as a code asset.
//
// Where the library comes from, first match wins:
// 1. The `lib_path` user define: a path to a ready library (for dev).
//    In the root pubspec.yaml of the app:
//      hooks:
//        user_defines:
//          dox_mysql_native:
//            lib_path: /path/to/libdox_mysql_native.so
// 2. A local build in `native/target/release` (for dev, same OS and CPU).
// 3. The ready-built library from the GitHub release, checked with sha256.
// 4. `cargo build` from source, when cargo is installed.
// When none works, no asset is added, and the build does not fail.
// `MysqlNativePool.isAvailable` is then false and says why.
import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:crypto/crypto.dart';
import 'package:hooks/hooks.dart';

const String _releases = 'https://github.com/dartondox/dox/releases/download';

/// sha256 of each release asset. The release workflow
/// (.github/workflows/native.yaml) builds the libraries on a
/// `dox_mysql_native-v*` tag and uploads them with `SHA256SUMS`. Then fill
/// this map before publishing to pub.dev:
/// `dart run bin/native_hashes.dart dox_mysql_native-v<version>`
const Map<String, String> _sha256 = <String, String>{
  'dox_mysql_native-linux-arm64.so':
      '4a53722bdf89c48325111a3ee0776c291a5e84ba69525129fc319d05798029a3',
  'dox_mysql_native-linux-x64.so':
      '2f12b51b4864300e8c3f88116fde979d4d3f40132c85ffbbcb091164fe10f33a',
  'dox_mysql_native-macos-arm64.dylib':
      'ba073184c33ac731c81ed9fb16213f591daa2f4a01e4f9a0852bb9591ccbf3d6',
  'dox_mysql_native-macos-x64.dylib':
      'be29ddab2680b3c487b02f20b58109ac411db3244e4cdb064fcec52db6595be7',
  'dox_mysql_native-windows-x64.dll':
      '4d356405a865111b430c59d403f45f0cbc237a8bcabc97fac3690ee001edf87b',
};

void main(List<String> args) async {
  await build(args, (BuildInput input, BuildOutputBuilder output) async {
    if (!input.config.buildCodeAssets) return;
    CodeConfig code = input.config.code;
    OS os = code.targetOS;
    Architecture arch = code.targetArchitecture;
    String fileName = os.dylibFileName('dox_mysql_native');
    bool host = os == OS.current && arch == Architecture.current;
    Uri native = input.packageRoot.resolve('native/');

    Uri? lib =
        _given(input) ??
        (host ? _local(native, fileName) : null) ??
        await _download(input, os, arch, fileName) ??
        (host ? await _cargo(input, native, fileName, output) : null);

    if (lib == null) {
      stderr.writeln(
        'dox_mysql_native: no native library for ${os.name}-${arch.name}.',
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
    throw StateError('dox_mysql_native: $path does not exist');
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
  String asset = 'dox_mysql_native-${os.name}-${arch.name}$ext';
  String? hash = _sha256[asset];
  if (hash == null) return null; // no release for this platform (yet)

  // the release tag has the package version, eg. dox_mysql_native-v3.0.0
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
      Uri.parse('$_releases/dox_mysql_native-v$version/$asset'),
    );
    HttpClientResponse res = await req.close();
    if (res.statusCode != 200) {
      stderr.writeln('dox_mysql_native: download $asset: ${res.statusCode}');
      return null;
    }
    List<int> bytes = <int>[
      for (List<int> chunk in await res.toList()) ...chunk,
    ];
    if (_sha(bytes) != hash) {
      stderr.writeln('dox_mysql_native: sha256 of $asset does not match');
      return null;
    }
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(bytes);
    return file.uri;
  } on IOException catch (error) {
    stderr.writeln('dox_mysql_native: download $asset failed: $error');
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
      stderr.writeln('dox_mysql_native: cargo build failed\n${result.stderr}');
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
