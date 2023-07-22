import 'dart:isolate';
import 'dart:math';

import 'package:async/async.dart';
import 'package:dox_core/dox_core.dart';
import 'package:dox_core/router/multi_thread_interfaces.dart';
import 'package:dox_core/router/multi_thread_isolate_handler.dart';
import 'package:dox_core/router/route_data.dart';

class DoxMultiThread {
  /// singleton
  static final DoxMultiThread _singleton = DoxMultiThread._internal();
  factory DoxMultiThread() => _singleton;
  DoxMultiThread._internal();

  /// list of thread created
  final List<DoxThread> _threads = <DoxThread>[];

  /// handle http request via thread
  /// ```
  /// DoxMultiThread().handleRequest(route, doxRequest, callback);
  /// ```
  void handleRequest(
    RouteData route,
    DoxRequest doxRequest,
    Function(dynamic) callback,
  ) async {
    DoxThread thread = _getRandomThread();
    thread.sendPort?.send([route, doxRequest]);
    dynamic response = await thread.stream.next;
    callback(response);
  }

  /// create threads
  /// ```
  /// await DoxMultiThread.create(3)
  /// ```
  Future<void> create(int count) async {
    for (int i = 0; i < count; i++) {
      await _createThread();
    }
  }

  /// create a thread
  Future<void> _createThread() async {
    ReceivePort receivePort = ReceivePort();

    Isolate isolate = await Isolate.spawn(
      multiThreadIsolateHandler,
      IsolateSpawnParameter(
        receivePort.sendPort,
        Dox().config,
        Dox().multiThreadServices,
      ),
    );

    /// convert receive port into stream
    StreamQueue<dynamic> stream = StreamQueue<dynamic>(receivePort);

    /// create new dox thread
    DoxThread thread = DoxThread(isolate, receivePort, stream);

    /// set sentPort get from isolate
    thread.sendPort = await thread.stream.next;

    /// set thread in array
    _threads.add(thread);
  }

  /// get random thread to handle http request
  DoxThread _getRandomThread() {
    Random random = Random();
    int randomIndex = random.nextInt(_threads.length);
    return _threads[randomIndex];
  }
}
