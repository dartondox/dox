import 'package:dox_core/dox_core.dart';

import '../handler.dart';
import '../middleware/custom_middleware.dart';
import '../requests/blog_request.dart';
import 'api_router.dart';

class Config extends AppConfig {
  @override
  String get appKey => '4HyiSrq4N5Nfg6bOadIhbFEI8zbUkpxt';

  int _serverPort = 50010;

  @override
  int get serverPort => _serverPort;

  set serverPort(int val) => _serverPort = val;

  @override
  CORSConfig get cors => CORSConfig(
        allowOrigin: '*',
      );

  @override
  Handler get responseHandler => ResponseHandler();

  @override
  List<dynamic> get globalMiddleware => <dynamic>[customMiddleware];

  @override
  Map<Type, Function()> get formRequests => <Type, Function()>{
        BlogRequest: () => BlogRequest(),
      };

  @override
  List<Router> get routers => <Router>[ApiRouter()];

  @override
  // ignore: overridden_fields
  CacheStore cacheStore = CacheStore.file;
}
