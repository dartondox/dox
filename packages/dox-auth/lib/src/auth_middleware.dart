// ignore_for_file: depend_on_referenced_packages
// ignore_for_file: constant_identifier_names

import 'package:dox_auth/dox_auth.dart';
import 'package:dox_query_builder/dox_query_builder.dart';

const String AUTH_REQUEST_KEY = 'dox_authentication_instance';

class AuthMiddleware {
  static Future<IDoxRequest> handle(IDoxRequest req) async {
    Auth auth = Auth();

    // verify token from header and get user data from database
    await auth.verifyToken(req);

    if (auth.isLoggedIn()) {
      /// merge into request auth
      req.merge(<String, dynamic>{AUTH_REQUEST_KEY: auth});
      return req;
    }
    throw UnAuthorizedException();
  }
}
