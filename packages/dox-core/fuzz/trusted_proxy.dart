import 'package:dox_core/http/request/trusted_proxy.dart';

import 'src/fuzz_target.dart';

/// The `X-Forwarded-For` and `X-Forwarded-Proto` headers, read like
/// `req.ip()` and `req.scheme()` behind a trusted proxy.
class TrustedProxyTarget extends FuzzTarget {
  TrustedProxyTarget();

  static const String remote = '10.0.0.1';

  final TrustedProxy proxy = TrustedProxy(const <String>[
    '10.0.0.0/8',
    '192.168.1.1',
    '::1',
  ]);

  @override
  String get name => 'trusted_proxy';

  @override
  String get library => 'package:dox_core/http/request/trusted_proxy.dart';

  @override
  List<String> get seeds => const <String>[
    '203.0.113.7',
    '203.0.113.7, 10.0.0.2',
    '6.6.6.6, 203.0.113.7:4711, 10.1.2.3, 192.168.1.1',
    '[2001:db8::1]:443, ::1',
    '::ffff:203.0.113.7, 10.0.0.2',
    'https, http',
  ];

  @override
  void check(String input) {
    String scheme = proxy.scheme(remote, input);
    if (scheme != 'http' && scheme != 'https') {
      throw StateError('scheme $scheme');
    }
    String ip = proxy.clientIp(remote, input);
    if (ip.isEmpty || ip.contains(',')) {
      throw StateError('client ip "$ip"');
    }

    /// one of our proxies is the client only when every hop is a proxy
    if (!proxy.trusts(ip)) return;
    for (String part in input.split(',')) {
      String hop = TrustedProxy.stripPort(part.trim());
      if (hop.isNotEmpty && !proxy.trusts(hop)) {
        throw StateError('client ip "$ip" is a proxy, but "$hop" is not');
      }
    }
  }
}

Future<void> main(List<String> args) => TrustedProxyTarget().run(args);
