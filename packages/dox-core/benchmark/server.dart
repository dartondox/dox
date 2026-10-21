import 'dart:io';

import 'package:dox_core/dox_core.dart';

import 'bench.dto.dart';

/// Small app used by the benchmark.
/// Usage: dart run benchmark/server.dart [isolates] [port]
class BenchRouter extends Router {
  @override
  void register() {
    Route.get('/json', (DoxRequest req) {
      return <String, dynamic>{
        'message': 'hello world',
        'id': 1,
        'tags': <String>['a', 'b', 'c'],
      };
    });

    Route.get('/user/{id}', (DoxRequest req, String id) {
      return <String, dynamic>{'id': id};
    });

    /// a POST body with 6 fields, checked by a DTO
    Route.post('/dto', (CreateMember body) {
      return <String, dynamic>{'name': body.name, 'age': body.age};
    });

    /// file stays on disk (temp file), nothing big in memory
    Route.post('/upload', (DoxRequest req) async {
      RequestFile file = req.input('file');
      return <String, dynamic>{'bytes': file.length};
    });

    /// loads the whole file into memory (old behaviour)
    Route.post('/upload/bytes', (DoxRequest req) async {
      RequestFile file = req.input('file');
      return <String, dynamic>{'bytes': (await file.bytes).length};
    });

    /// peak memory of this process, in MB
    Route.get('/rss', (DoxRequest req) {
      return <String, dynamic>{'max_rss_mb': ProcessInfo.maxRss ~/ 1048576};
    });
  }
}

class BenchHandler extends ResponseHandlerInterface {
  @override
  DoxResponse handle(DoxResponse res) => res;
}

void main(List<String> args) async {
  int isolates = args.isNotEmpty ? int.parse(args[0]) : 1;
  int port = args.length > 1 ? int.parse(args[1]) : 4000;
  Dox().initialize(
    AppConfig(
      maxMultipartSize: 200 * 1024 * 1024,
      appKey: '4HyiSrq4N5Nfg6bOadIhbFEI8zbUkpxt',
      serverPort: port,
      totalIsolate: isolates,
      responseHandler: BenchHandler(),
      dtos: <DtoSchema<Object>>[CreateMember.schema],
      routers: <Router>[BenchRouter()],
      globalMiddleware: <dynamic>[
        LogMiddleware(enabled: Platform.environment['LOG'] == '1'),
      ],
    ),
  );
  await Dox().startServer();
  print('ready');
}
