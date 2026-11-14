import 'dart:io';

import 'package:dox_core/interfaces/core_flags.dart';

class Env {
  static final Env _singleton = Env._internal();

  factory Env() {
    return _singleton;
  }

  Map<String, String> _env = <String, String>{};

  /// True after the first [load], or after [env] was set.
  bool _loaded = false;

  /// The values of the `.env` file. The first read loads the file, so a
  /// read gives the same answer whether or not something loaded it before.
  /// After that it is a plain map read: the file is never read again.
  Map<String, String> get env {
    if (!_loaded) load();
    return _env;
  }

  /// Sets the values, for tests. It counts as loaded: the next read does
  /// not put the `.env` file on top. Call [load] on an empty map to read
  /// the file again.
  set env(Map<String, String> value) {
    _env = value;
    _loaded = true;
  }

  Env._internal();

  /// Reads the `.env` file once.
  ///
  /// When the app runs its tests, it also reads `.env.testing` (next to
  /// `.env`). Its keys win over the keys of `.env`. A real environment
  /// variable still wins over both. [testing] is [isTesting] by default.
  void load({File? file, bool? testing}) {
    _loaded = true;
    if (_env.isEmpty) {
      expanded = flags.envExpand;
      _env = _loadEnv(file: file, testing: testing ?? isTesting);
    }
  }

  /// The flags the `.env` file is read with. Only `envExpand` is used.
  /// Set it at the top of `main()`, before any env value is read: the
  /// file is read once, before `AppConfig` exists. See
  /// `CoreFlags.envExpand`. The server isolates read `.env` the same way
  /// as the main isolate, without more setup.
  static CoreFlags flags = const CoreFlags();

  /// True when the loaded `.env` was read with `envExpand`.
  bool expanded = false;

  /// True when `APP_ENV=testing` is a real environment variable, or the
  /// code runs under `dart test`.
  static bool get isTesting {
    if (Platform.environment['APP_ENV'] == 'testing') return true;
    // ponytail: `dart test` runs a bootstrap from a `dart_test.*` temp
    // folder. Use APP_ENV=testing if a test runner ever changes this.
    String script = Platform.script.path;
    return script.contains('/dart_test.') || script.endsWith('_test.dart');
  }

  /// get env value
  /// ```
  /// Env.get('APP_KEY');
  /// Env.get('APP_KEY', 'with_default_value_if_null');
  /// Env.get<int>('PORT', 3000); (This will return int type)
  /// Env.get<num>('PORT', 3000); (This will return num type)
  /// Env.get<bool>('DEBUG', false); (true/1/yes/on is true)
  /// Env.get<String?>('APP_NAME'); (null when it is not set)
  /// ```
  /// A missing or empty key gives the default. With no default:
  /// - a nullable type (`String?`, `dynamic`) gives `null`
  /// - `String` gives an empty string, never the text "null"
  /// - `int`, `num`, `double` and `bool` throw an [ArgumentError]
  ///
  /// A real environment variable wins over the `.env` file, so a docker
  /// or systemd deploy can pass config without a `.env` file.
  /// The first read loads `.env` when nothing did yet, so the answer is the
  /// same whether or not something read the env before.
  static T get<T>(String key, [dynamic defaultValue]) {
    String? value = Platform.environment[key] ?? Env().env[key];
    // only spaces counts as empty, the same as `EnvReader`
    if (value == null ||
        value.trim().isEmpty ||
        value.trim().toLowerCase() == 'null') {
      if (defaultValue == null) return _missing<T>(key);
      if (defaultValue is T) return defaultValue;
      value = defaultValue.toString();
    }
    return _cast<T>(key, value);
  }

  /// `APP_ENV` in lower case. Empty when it is not set, which means
  /// production. Like [get], it loads `.env` first when nothing did yet.
  static String get appEnv => get<String>('APP_ENV').toLowerCase();

  static T _missing<T>(String key) {
    if (null is T) return null as T;
    if (<T>[] is List<String>) return '' as T;
    throw ArgumentError('Env key "$key" is not set and has no default');
  }

  static T _cast<T>(String key, String value) {
    if (<T>[] is List<String>) return value as T;
    String type = T.toString().replaceAll('?', '');
    Object? result = switch (type) {
      'int' => int.tryParse(value),
      'double' => double.tryParse(value),
      'num' => num.tryParse(value),
      'bool' => _bool(value),
      _ => value,
    };
    if (result == null) {
      // not the value: it may be a secret
      throw ArgumentError('Env key "$key" is not a valid $type');
    }
    return result as T;
  }

  static bool? _bool(String value) {
    switch (value.toLowerCase()) {
      case 'true' || '1' || 'yes' || 'on':
        return true;
      case 'false' || '0' || 'no' || 'off':
        return false;
    }
    return null;
  }

  /// load env from .env of project directory, and .env.testing on top
  /// of it when [testing]
  Map<String, String> _loadEnv({File? file, bool testing = false}) {
    File envFile = file ?? File('${Directory.current.path}/.env');
    Map<String, String> data = _read(envFile);
    if (testing) {
      data.addAll(
        _read(File('${envFile.parent.path}/.env.testing'), known: data),
      );
    }
    return data;
  }

  static Map<String, String> _read(
    File file, {
    Map<String, String> known = const <String, String>{},
  }) {
    if (!file.existsSync()) return <String, String>{};
    return parse(
      file.readAsStringSync(),
      known: known,
      expand: flags.envExpand,
    );
  }

  /// Reads the text of a `.env` file.
  /// - `KEY=value`, one per line. Lines that start with `#` are comments.
  ///   `export KEY=value` is read like `KEY=value`.
  /// - `KEY=value # note`: a `#` after a space starts a comment.
  /// - `KEY="a # b"`: quotes (`"`, `'` or `` ` ``) keep the value as it is,
  ///   also a `#`. The quotes are removed.
  /// - `KEY=abc#def` stays `abc#def` and `KEY=#fff` stays `#fff` (no space
  ///   before the `#`).
  /// - One line is one value. A quoted value can not go over more lines.
  ///   With [expand], write a new line as `\n` inside `"` quotes.
  ///
  /// With [expand] (`CoreFlags.envExpand`):
  /// - `${OTHER}` is the value of `OTHER`, in an unquoted or a `"` value.
  ///   A real environment variable wins, then a key above this line (or
  ///   in [known]). An unknown name stays as it is: `${OTHER}`.
  /// - In a `"` value, `\n`, `\t`, `\"`, `\\` and `\$` become a new line,
  ///   a tab, `"`, `\` and `$`. A `'` or `` ` `` value stays raw.
  static Map<String, String> parse(
    String contents, {
    Map<String, String> known = const <String, String>{},
    bool expand = false,
  }) {
    Map<String, String> data = <String, String>{};
    String? lookup(String name) =>
        Platform.environment[name] ?? data[name] ?? known[name];
    for (String line in contents.split('\n')) {
      String text = line.trim();
      if (text.isEmpty || text.startsWith('#')) continue;
      text = text.replaceFirst(_export, '');
      int equal = text.indexOf('=');
      if (equal < 1) continue;
      data[text.substring(0, equal).trim()] = _value(
        text.substring(equal + 1),
        expand ? lookup : null,
      );
    }
    return data;
  }

  /// a `#` after a space or tab. Checked on the text right after `=`, so
  /// `KEY=#fff` keeps `#fff` and `KEY= #x` is a comment.
  static final RegExp _comment = RegExp(r'\s#');

  static final RegExp _export = RegExp(r'^export\s+');

  static final RegExp _variable = RegExp(r'\$\{([A-Za-z_][A-Za-z0-9_]*)\}');

  /// [lookup] is null when `envExpand` is off: the value is read as it
  /// is written.
  static String _value(String raw, String? Function(String)? lookup) {
    String value = raw.trim();
    if (lookup != null && value.startsWith('"')) {
      String? text = _doubleQuoted(value, lookup);
      if (text != null) return text;
    } else if (value.isNotEmpty && '"\'`'.contains(value[0])) {
      int end = value.indexOf(value[0], 1);
      if (end > 0) return value.substring(1, end);
    }
    Match? comment = _comment.firstMatch(raw);
    if (comment != null) value = raw.substring(0, comment.start);
    value = value.trim();
    if (lookup == null) return value;
    return value.replaceAllMapped(
      _variable,
      (Match match) => lookup(match[1]!) ?? match[0]!,
    );
  }

  /// the text inside the `"` quotes at the start of [value], with escapes
  /// and `${NAME}` done. null when the closing quote is missing.
  static String? _doubleQuoted(String value, String? Function(String) lookup) {
    StringBuffer out = StringBuffer();
    for (int i = 1; i < value.length; i++) {
      String char = value[i];
      if (char == '"') return out.toString();
      if (char == r'\' && i + 1 < value.length) {
        String next = value[++i];
        out.write(switch (next) {
          'n' => '\n',
          't' => '\t',
          '"' || r'\' || r'$' => next,
          _ => '\\$next',
        });
        continue;
      }
      Match? match = char == r'$' ? _variable.matchAsPrefix(value, i) : null;
      if (match != null) {
        out.write(lookup(match[1]!) ?? match[0]);
        i = match.end - 1;
        continue;
      }
      out.write(char);
    }
    return null;
  }
}
