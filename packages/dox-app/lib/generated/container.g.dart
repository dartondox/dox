// GENERATED CODE - DO NOT MODIFY BY HAND
// Made by dox_builder. Run `dart run build_runner build`.
// ignore_for_file: type=lint

import 'package:dox_core/dox_core.dart';
import 'package:dox_app/app/http/controllers/api.controller.dart' as i1;
import 'package:dox_app/app/http/controllers/auth.controller.dart' as i2;
import 'package:dox_app/app/http/controllers/blog.controller.dart' as i3;
import 'package:dox_app/app/http/controllers/web.controller.dart' as i4;
import 'package:dox_app/app/http/services/blog.service.dart' as i5;
import 'package:dox_app/routes/api.dart' as i6;
import 'package:dox_app/routes/web.dart' as i7;
import 'package:dox_app/services/auth_service.dart' as i8;
import 'package:dox_app/services/orm_service.dart' as i9;
import 'package:dox_app/app/models/blog/blog.model.dart' as i10;
import 'package:dox_app/app/models/category/category.model.dart' as i11;
import 'package:dox_app/app/models/user/user.model.dart' as i12;

/// Puts every class of the app into the container: the
/// `@Inject()` classes, routers, services and model binders.
/// Use it in `AppConfig(container: registerContainer)`.
void registerContainer(IocContainer c) {
  c.singleton<i1.ApiController>((IocContainer c) => i1.ApiController());
  c.singleton<i2.AuthController>((IocContainer c) => i2.AuthController());
  c.singleton<i3.BlogController>(
    (IocContainer c) => i3.BlogController(c.get<i5.BlogService>()),
  );
  c.singleton<i4.WebController>((IocContainer c) => i4.WebController());
  c.singleton<i5.BlogService>((IocContainer c) => i5.BlogService());
  c.router<i6.ApiRouter>((IocContainer c) => i6.ApiRouter());
  c.router<i7.WebRouter>((IocContainer c) => i7.WebRouter());
  c.service<i8.AuthService>((IocContainer c) => i8.AuthService());
  c.service<i9.ORMService>((IocContainer c) => i9.ORMService());
  c.bindModel<i10.Blog>((String id) {
    int? key = int.tryParse(id);
    if (key == null) return null;
    return i10.Blog().find(key);
  });
  c.bindModel<i11.Category>((String id) {
    int? key = int.tryParse(id);
    if (key == null) return null;
    return i11.Category().find(key);
  });
  c.bindModel<i12.User>((String id) {
    int? key = int.tryParse(id);
    if (key == null) return null;
    return i12.User().find(key);
  });
}
