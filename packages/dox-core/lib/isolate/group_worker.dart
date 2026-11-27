import 'dart:async';
import 'dart:ffi';
import 'dart:isolate';

import 'package:dox_core/dox_core.dart';
import 'package:dox_core/isolate/group_identity.dart';
import 'package:dox_core/middleware/rate_limit_counter.dart';
import 'package:dox_core/server/dox_server.dart';
import 'package:dox_core/session/session_memory_store.dart';

/// What a server isolate does when it runs in its own isolate group.
/// It is the `isolateHandler` of `DoxIsolate`, but the config, providers
/// and routes are not sent: the group runs the `main()` of the app, so
/// it builds them itself. Only the ports come from the primary isolate.
class GroupWorker {
  /// the most time to wait for the ports of the primary isolate
  static Duration handshakeTimeout = const Duration(seconds: 30);

  /// Say hello to the primary, get its ports, then start the providers
  /// and the server like `isolateHandler`. Call it from `startServer()`,
  /// after the providers of the config are added.
  static Future<void> run(GroupIdentity identity) async {
    ReceivePort inbox = ReceivePort();
    try {
      postSendPort(identity.primaryPort, inbox.sendPort);
      Object? message = await inbox.first.timeout(
        handshakeTimeout,
        onTimeout: () => throw StateError(
          'isolate ${identity.isolateId} got no answer from the primary '
          'isolate in ${handshakeTimeout.inSeconds} seconds',
        ),
      );
      List<Object?> ports = message as List<Object?>;
      RateLimitCounter.instance.connect(ports[1] as SendPort?);
      SessionMemoryStore.instance.connect(ports[2] as SendPort?);
      IsolateBus.instance.connect(ports[3] as SendPort?, identity.isolateId);
      SendPort control = ports[0] as SendPort;

      AppConfig config = Dox().config;
      await Dox().startProviders();
      DoxServer().setResponseHandler(config.responseHandler);
      await DoxServer().listen(
        DoxServer.portFor(config.serverPort),
        address: DoxServer.hostFor(config.host),
      );

      /// the primary sends a reply port here to stop this isolate
      ReceivePort commands = ReceivePort();
      commands.listen((dynamic reply) async {
        commands.close();
        await Dox().stopIsolate();
        (reply as SendPort).send(true);
      });
      control.send(commands.sendPort);
    } finally {
      inbox.close();
    }
  }

  /// Send [own] to the port [target] of another isolate group. A port
  /// of another group is only known by its number, so the message is
  /// built by hand: a `Dart_CObject` of the type `kSendPort`.
  // ponytail: needs `malloc` and `free` in the process, so Windows is
  // out. Windows runs one isolate anyway. Use package:ffi if it is added.
  static void postSendPort(int target, SendPort own) {
    DynamicLibrary process = DynamicLibrary.process();
    Pointer<Uint8> Function(int) malloc = process
        .lookupFunction<
          Pointer<Uint8> Function(IntPtr),
          Pointer<Uint8> Function(int)
        >('malloc');
    void Function(Pointer<Uint8>) free = process
        .lookupFunction<
          Void Function(Pointer<Uint8>),
          void Function(Pointer<Uint8>)
        >('free');
    Pointer<Uint8> object = malloc(64);
    for (int i = 0; i < 64; i++) {
      object[i] = 0;
    }
    // Dart_CObject: type (4 bytes), then the port id and the origin id
    object.cast<Int32>().value = 9;
    (object + 8).cast<Int64>().value = own.nativePort;
    (object + 16).cast<Int64>().value = 0;
    bool Function(int, Pointer<Uint8>) post = NativeApi.postCObject
        .cast<NativeFunction<Bool Function(Int64, Pointer<Uint8>)>>()
        .asFunction<bool Function(int, Pointer<Uint8>)>();
    bool sent = post(target, object);
    free(object);
    if (!sent) throw StateError('the primary isolate does not take messages');
  }
}
