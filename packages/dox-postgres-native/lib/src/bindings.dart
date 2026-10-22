import 'dart:ffi';

/// FFI calls into the Rust library. The build hook (hook/build.dart) ships
/// the library as the code asset of this file.

/// The ABI version the Dart side expects. Must match `ABI_VERSION` in Rust.
const int abiVersion = 1;

@Native<Int32 Function()>(symbol: 'dpg_version', isLeaf: true)
external int dpgVersion();

@Native<Int32 Function(Pointer<Void>)>(symbol: 'dpg_init')
external int dpgInit(Pointer<Void> dlData);

@Native<Int64 Function(Pointer<Uint8>, Int64, Int64, Int64)>(
  symbol: 'dpg_connect',
  isLeaf: true,
)
external int dpgConnect(
  Pointer<Uint8> cfg,
  int length,
  int maxSize,
  int threads,
);

@Native<Void Function(Int64)>(symbol: 'dpg_close')
external void dpgClose(int pool);

@Native<Int64 Function(Int64)>(symbol: 'dpg_open', isLeaf: true)
external int dpgOpen(int sendPort);

@Native<Void Function(Int64)>(symbol: 'dpg_release', isLeaf: true)
external void dpgRelease(int sink);

@Native<Void Function(Int64, Pointer<Uint8>, Int64)>(
  symbol: 'dpg_submit',
  isLeaf: true,
)
external void dpgSubmit(int sink, Pointer<Uint8> data, int length);
