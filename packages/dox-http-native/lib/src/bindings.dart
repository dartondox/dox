import 'dart:ffi';

/// FFI calls into the Rust library. The build hook (hook/build.dart) ships
/// the library as the code asset of this file.

/// The ABI version the Dart side expects. Must match `ABI_VERSION` in Rust.
const int abiVersion = 4;

@Native<Int32 Function()>(symbol: 'dox_version', isLeaf: true)
external int doxVersion();

@Native<Int32 Function(Pointer<Void>)>(symbol: 'dox_init')
external int doxInit(Pointer<Void> dlData);

/// [family] 0 is all interfaces, 4 is IPv4 (in [addrLo]), 6 is IPv6.
@Native<
  Int64 Function(Int32, Int64, Int64, Int64, Int64, Int32, Uint64, Uint64)
>(symbol: 'dox_start')
external int doxStart(
  int port,
  int sendPort,
  int maxBody,
  int maxMultipart,
  int bodyTimeoutMs,
  int family,
  int addrHi,
  int addrLo,
);

@Native<Int32 Function(Int64)>(symbol: 'dox_port', isLeaf: true)
external int doxPort(int handle);

/// Stop accepting. Open connections close after their current answer.
/// Rust posts one byte to the port when they are all closed.
@Native<Void Function(Int64)>(symbol: 'dox_shutdown')
external void doxShutdown(int handle);

@Native<Void Function(Int64)>(symbol: 'dox_stop')
external void doxStop(int handle);

@Native<Void Function(Int64, Pointer<Uint8>, Int64)>(
  symbol: 'dox_respond_batch',
  isLeaf: true,
)
external void doxRespondBatch(int handle, Pointer<Uint8> data, int length);
