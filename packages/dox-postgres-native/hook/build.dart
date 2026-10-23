// Ships the native library of dox_postgres_native as a code asset.
//
// Where the library comes from, first match wins:
// 1. The `lib_path` user define: a path to a ready library (for dev).
//    In the root pubspec.yaml of the app:
//      hooks:
//        user_defines:
//          dox_postgres_native:
//            lib_path: /path/to/libdox_postgres_native.so
// 2. A local build in `native/target/release` (for dev, same OS and CPU).
// 3. The ready-built library from the GitHub release, checked with sha256.
// 4. `cargo build` from source, when cargo is installed.
// When none works, no asset is added. `PgNativePool.open` then throws.
// The build never fails because of this package.
import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:crypto/crypto.dart';
import 'package:hooks/hooks.dart';

const String _releases = 'https://github.com/dartondox/dox/releases/download';

/// sha256 of each release asset. The release workflow
/// (.github/workflows/native.yaml) builds the libraries on a
/// `dox_postgres_native-v*` tag and uploads them with `SHA256SUMS`. Then fill
/// this map before publishing to pub.dev:
/// `dart run bin/native_hashes.dart dox_postgres_native-v<version>`
const Map<String, String> _sha256 = <String, String>{
  'dox_postgres_native-linux-arm64.so':
      'dcf297fc1168c4c085078710e6d99bd025a75202b2a33098c70316c6392d3d37',
  'dox_postgres_native-linux-x64.so':
      '1d42e47e1cd372a7a41b8f9dac514819ec49e15466c52881bdd762b5c80f227b',
  'dox_postgres_native-macos-arm64.dylib':
      'a659662c4bcf82b09098a83a4d6a4dc89fdd29058349e7b739a484dabe6fa485',
  'dox_postgres_native-macos-x64.dylib':
      'b255087ea02462f18fd47d1bcf3ec153d9eb71a7c7365ba0dd1ffc4d0396ef10',
  'dox_postgres_native-windows-x64.dll':
      '2b97c8dd8fabb83be6a56d532b6cfb426c2987b00583a7b35768b1156b1b3325',
};

void main(List<String> args) async {
  await build(args, (BuildInput input, BuildOutputBuilder output) async {
    if (!input.config.buildCodeAssets) return;
    CodeConfig code = input.config.code;
    OS os = code.targetOS;
    Architecture arch = code.targetArchitecture;
    String fileName = os.dylibFileName('dox_postgres_native');
    bool host = os == OS.current && arch == Architecture.current;
    Uri native = input.packageRoot.resolve('native/');

    Uri? lib =
        _given(input) ??
        (host ? _local(native, fileName) : null) ??
        await _download(input, os, arch, fileName) ??
        (host ? await _cargo(input, native, fileName, output) : null);

    if (lib == null) {
      stderr.writeln(
        'dox_postgres_native: no native library for ${os.name}-${arch.name}. '
        'Install Rust (rustup) or use the Dart postgres driver.',
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
    throw StateError('dox_postgres_native: $path does not exist');
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
  String asset = 'dox_postgres_native-${os.name}-${arch.name}$ext';
  String? hash = _sha256[asset];
  if (hash == null) return null; // no release for this platform (yet)

  // the release tag has the package version, eg. dox_postgres_native-v3.0.0
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
      Uri.parse('$_releases/dox_postgres_native-v$version/$asset'),
    );
    HttpClientResponse res = await req.close();
    if (res.statusCode != 200) {
      stderr.writeln('dox_postgres_native: download $asset: ${res.statusCode}');
      return null;
    }
    List<int> bytes = <int>[
      for (List<int> chunk in await res.toList()) ...chunk,
    ];
    if (_sha(bytes) != hash) {
      stderr.writeln('dox_postgres_native: sha256 of $asset does not match');
      return null;
    }
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(bytes);
    return file.uri;
  } on IOException catch (error) {
    stderr.writeln('dox_postgres_native: download $asset failed: $error');
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
      stderr.writeln(
        'dox_postgres_native: cargo build failed\n${result.stderr}',
      );
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
