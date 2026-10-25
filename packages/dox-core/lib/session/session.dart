import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

/// The session of one request: `req.session`. `SessionMiddleware` makes
/// it.
///
/// The data is read on first use, so a request that never uses the
/// session costs nothing. It is saved at the end of the request only
/// when it changed.
/// ```
/// req.session.put('cart', <int>[1, 2]);
/// List<dynamic>? cart = req.session.get('cart');
/// req.session.flash('message', 'Saved'); // the next request only
/// ```
/// Values must be JSON types (Map, List, String, num, bool, null).
class Session {
  /// [id] is the id of a stored session (`cache` driver). [_read] gives
  /// the stored session on first use, or null for a new one.
  Session({this.id, this._read});

  /// Fields of a request that are never kept as old input.
  static const List<String> dontFlash = <String>[
    'password',
    'password_confirmation',
    'current_password',
  ];

  /// The key of the validation errors, see [flashErrors].
  static const String errorsKey = 'errors';

  /// The key of the old input, see [flashErrors].
  static const String oldInputKey = '_old_input';

  static final Random _random = Random.secure();

  /// The session id for the `cache` driver. null until it is saved.
  String? id;

  /// The id before [regenerate], removed from the store on save.
  String? previousId;

  Object? Function()? _read;
  Map<String, dynamic>? _data;

  /// flash keys from the request before. removed at the end of this one.
  List<String> _flashOld = <String>[];

  /// flash keys of this request. they live one more request.
  List<String> _flashNew = <String>[];
  String? _token;

  /// when it was saved, in milliseconds since epoch
  int _savedAt = 0;
  bool _changed = false;

  /// The data, read on first use.
  Map<String, dynamic> _load() {
    Map<String, dynamic>? data = _data;
    if (data != null) return data;
    Object? stored = _read?.call();
    _read = null;
    data = <String, dynamic>{};
    if (stored is Map) {
      Object? values = stored['data'];
      if (values is Map) data.addAll(values.cast<String, dynamic>());
      Object? flash = stored['flash'];
      if (flash is List) _flashOld = flash.cast<String>().toList();
      _token = stored['token'] as String?;
      _savedAt = (stored['at'] as num?)?.toInt() ?? 0;
    }
    return _data = data;
  }

  /// True when the request used the session.
  bool get started => _data != null;

  /// True when the request changed the session.
  bool get changed => _changed;

  /// The value of [key], or [defaultValue] when it is missing.
  dynamic get(String key, [Object? defaultValue]) {
    return _load()[key] ?? defaultValue;
  }

  /// Store [value] under [key].
  void put(String key, Object? value) {
    _load()[key] = value;
    _changed = true;
  }

  /// True when [key] has a value that is not null.
  bool has(String key) => _load()[key] != null;

  /// Remove [key].
  void forget(String key) {
    if (_load().remove(key) != null) _changed = true;
  }

  /// All values. Changes to the map do not change the session.
  Map<String, dynamic> all() => Map<String, dynamic>.of(_load());

  /// Remove all values, flash data too.
  void flush() {
    _load().clear();
    _flashOld = <String>[];
    _flashNew = <String>[];
    _changed = true;
  }

  /// The value of [key], removed from the session.
  dynamic pull(String key, [Object? defaultValue]) {
    dynamic value = get(key, defaultValue);
    forget(key);
    return value;
  }

  /// Store [value] under [key] for this request and the next one that
  /// uses the session.
  void flash(String key, Object? value) {
    put(key, value);
    if (!_flashNew.contains(key)) _flashNew.add(key);
  }

  /// Keep all flash data for one more request.
  void reflash() => keep(_flashOld);

  /// Keep the flash data of [keys] for one more request.
  void keep(List<String> keys) {
    _load();
    for (String key in keys) {
      if (_flashOld.contains(key) && !_flashNew.contains(key)) {
        _flashNew.add(key);
      }
    }
    _changed = true;
  }

  /// Give the session a new id and a new CSRF token, and keep the data.
  /// Call it after login, so an old id from before the login is no use.
  void regenerate() {
    _load();
    if (id != null) previousId = id;
    id = null;
    _token = _randomToken();
    _changed = true;
  }

  /// Remove all data and give the session a new id. Use it on logout.
  void invalidate() {
    flush();
    regenerate();
  }

  /// The CSRF token of the session. Made on first use.
  String get token {
    _load();
    String? token = _token;
    if (token != null) return token;
    _changed = true;
    return _token = _randomToken();
  }

  /// Flash validation [errors] and the old [input] for the next request.
  /// Password fields ([dontFlash]) and uploaded files are not kept.
  /// ```
  /// req.session.flashErrors({'email': 'The email is taken'},
  ///     input: req.all());
  /// return back(req);
  /// ```
  void flashErrors(Object errors, {Map<String, dynamic>? input}) {
    flash(errorsKey, errors);
    if (input == null) return;
    flash(oldInputKey, <String, dynamic>{
      for (MapEntry<String, dynamic> entry in input.entries)
        if (!dontFlash.contains(entry.key) && _isJson(entry.value))
          entry.key: entry.value,
    });
  }

  /// The flashed validation errors, like `{'email': 'The email is taken'}`.
  /// Empty when there are none.
  Map<String, dynamic> get errors {
    Object? errors = get(errorsKey);
    if (errors is Map) return errors.cast<String, dynamic>();
    return <String, dynamic>{};
  }

  /// The old input of [key] from the request before, see [flashErrors].
  dynamic old(String key, [Object? defaultValue]) {
    Object? input = get(oldInputKey);
    if (input is Map) return input[key] ?? defaultValue;
    return defaultValue;
  }

  /// Internal, for `SessionMiddleware`: the session to store, or null
  /// when nothing changed. Flash data of the request before is removed
  /// here. A session older than half of [lifetime] is stored again, so
  /// it does not end while it is used.
  Map<String, dynamic>? toStore(Duration lifetime) {
    Map<String, dynamic>? data = _data;
    if (data == null) return null;
    if (_flashOld.isNotEmpty) {
      for (String key in _flashOld) {
        if (!_flashNew.contains(key)) data.remove(key);
      }
      _flashOld = <String>[];
      _changed = true;
    }
    int now = DateTime.now().millisecondsSinceEpoch;
    if (now - _savedAt > lifetime.inMilliseconds ~/ 2) _changed = true;
    if (!_changed) return null;
    _savedAt = now;
    return <String, dynamic>{
      'data': data,
      'flash': _flashNew,
      'token': _token,
      'at': now,
    };
  }

  static bool _isJson(Object? value) {
    return value == null ||
        value is String ||
        value is num ||
        value is bool ||
        value is Map ||
        value is List;
  }

  static String _randomToken() {
    Uint8List bytes = Uint8List(30);
    for (int i = 0; i < bytes.length; i++) {
      bytes[i] = _random.nextInt(256);
    }
    return base64Url.encode(bytes);
  }

  /// A new random session id.
  static String newId() => _randomToken();
}
