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
// Outside the pub cache (this repo, or a path or git dependency), 4 comes
// before 3, because the source may be newer than the release.
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
      '74c0605a25cab367bfbc4b3e05640a94631474115d783418734b6727c66e22ca',
  'dox_mysql_native-linux-x64.so':
      'fdd6e5d5dcf4115dad6dcd795d781149dafbec5a686f87f82d10c1b60489b384',
  'dox_mysql_native-macos-arm64.dylib':
      '6471fe27968d6a396a5fc402241f7f99c114563c2cdde0e8870340f4893fa975',
  'dox_mysql_native-macos-x64.dylib':
      'd958e63a7f5a6ec9353398fab44875f9e2299c8aaf1c204408d29c9dc302032b',
  'dox_mysql_native-windows-x64.dll':
      '0a89ddb06a524c4089f985bad22223b50f28fc7189ad45c88e385e05a5070552',
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
    // From pub.dev the source matches the release, so download first. In the
    // repo, or as a path or git dependency, the source may be newer than the
    // release (eg. a new ABI), so build it with cargo first.
    bool published = input.packageRoot.pathSegments.contains('hosted');

    Uri? lib =
        _given(input) ??
        (host ? _local(native, fileName) : null) ??
        (published ? await _download(input, os, arch, fileName) : null) ??
        (host ? await _cargo(input, native, fileName, output) : null) ??
        (published ? null : await _download(input, os, arch, fileName));

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
  // a stalled download must not hang the build forever
  HttpClient client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 30);
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
      for (List<int> chunk
          in await res.timeout(const Duration(seconds: 60)).toList())
        ...chunk,
    ];
    if (_sha(bytes) != hash) {
      stderr.writeln('dox_mysql_native: sha256 of $asset does not match');
      return null;
    }
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(bytes);
    return file.uri;
  } on Exception catch (error) {
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
