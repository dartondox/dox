import 'dart:io';
import 'dart:math';

void generateKey() {
  const chars =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  final random = Random.secure();
  var secret = String.fromCharCodes(
    Iterable.generate(
      32,
      (_) => chars.codeUnitAt(random.nextInt(chars.length)),
    ),
  );
  print("\x1B[34m$secret : Key have been updated successfully in .env!\x1B[0m");
  overrideKey(secret);
}

/// Sets `APP_KEY` in `.env` to [secret].
///
/// Only the `APP_KEY` line changes. Every other line (comments, blank
/// lines, quotes, values with more than one `=`) stays as it is, in order.
/// When there is no `APP_KEY`, it is added as the first line.
void overrideKey(String secret, [String? path]) {
  final file = File(path ?? '${Directory.current.path}/.env');
  List<String> lines = file.readAsStringSync().split('\n');
  bool found = false;
  for (int i = 0; i < lines.length; i++) {
    String line = lines[i];
    int eq = line.indexOf('=');
    if (eq < 0 || line.substring(0, eq).trim() != 'APP_KEY') continue;
    // Keep a Windows line end (\r) when the file has one.
    String end = line.endsWith('\r') ? '\r' : '';
    lines[i] = 'APP_KEY=$secret$end';
    found = true;
  }
  if (!found) lines.insert(0, 'APP_KEY=$secret');
  file.writeAsStringSync(lines.join('\n'));
}
