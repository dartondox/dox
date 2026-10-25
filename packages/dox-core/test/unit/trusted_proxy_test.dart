import 'package:dox_core/http/request/trusted_proxy.dart';
import 'package:test/test.dart';

void main() {
  group('TrustedProxy |', () {
    test('off by default: headers are ignored', () {
      TrustedProxy proxy = TrustedProxy(<String>[]);
      expect(proxy.enabled, false);
      expect(proxy.clientIp('8.8.8.8', '1.2.3.4'), '8.8.8.8');
      expect(proxy.scheme('8.8.8.8', 'https'), 'http');
    });

    test('untrusted peer can not fake its ip', () {
      TrustedProxy proxy = TrustedProxy(<String>['10.0.0.0/8']);
      expect(proxy.clientIp('8.8.8.8', '1.2.3.4'), '8.8.8.8');
      expect(proxy.scheme('8.8.8.8', 'https'), 'http');
    });

    test('trusted peer: right-most untrusted hop is the client', () {
      TrustedProxy proxy = TrustedProxy(<String>['10.0.0.0/8', '127.0.0.1']);
      expect(proxy.clientIp('10.1.2.3', '1.2.3.4'), '1.2.3.4');
      expect(proxy.clientIp('10.1.2.3', 'fake, 1.2.3.4, 10.0.0.5'), '1.2.3.4');
      expect(proxy.clientIp('127.0.0.1', null), '127.0.0.1');
      expect(proxy.scheme('10.1.2.3', 'https'), 'https');
      expect(proxy.scheme('10.1.2.3', 'HTTPS, http'), 'https');
    });

    test('a hop with a port is read without the port', () {
      TrustedProxy proxy = TrustedProxy(<String>['10.0.0.0/8', '::1']);
      expect(proxy.clientIp('10.1.2.3', '1.2.3.4:5678'), '1.2.3.4');
      expect(proxy.clientIp('10.1.2.3', '[2001:db8::1]:5678'), '2001:db8::1');
      expect(proxy.clientIp('10.1.2.3', '2001:db8::1'), '2001:db8::1');
      expect(proxy.clientIp('10.1.2.3', '1.2.3.4, 10.0.0.5:80'), '1.2.3.4');
      expect(proxy.clientIp('10.1.2.3', '1.2.3.4, [::1]:80'), '1.2.3.4');
      expect(proxy.clientIp('10.1.2.3', '1.2.3.4, ::1'), '1.2.3.4');
      expect(TrustedProxy.stripPort('[::1]'), '::1');
    });

    test('wildcard trusts only the direct peer, not the hops', () {
      TrustedProxy proxy = TrustedProxy(<String>['*']);
      // the client sent `X-Forwarded-For: 6.6.6.6`, the proxy added its ip
      expect(proxy.clientIp('10.1.2.3', '6.6.6.6, 1.2.3.4'), '1.2.3.4');
      expect(proxy.clientIp('10.1.2.3', '1.2.3.4'), '1.2.3.4');
      expect(proxy.scheme('10.1.2.3', 'https'), 'https');

      // a listed range is still skipped
      TrustedProxy both = TrustedProxy(<String>['*', '10.0.0.0/8']);
      expect(both.clientIp('9.9.9.9', 'fake, 1.2.3.4, 10.0.0.5'), '1.2.3.4');
    });

    test('ipv4-mapped ipv6 peer matches ipv4 rule', () {
      TrustedProxy proxy = TrustedProxy(<String>['172.16.0.0/12']);
      expect(proxy.trusts('::ffff:172.18.0.2'), true);
      expect(proxy.trusts('172.32.0.1'), false);
    });

    test('ipv4-mapped ipv6 becomes plain ipv4', () {
      expect(TrustedProxy.normalize('::ffff:127.0.0.1'), '127.0.0.1');
      expect(TrustedProxy.normalize('::FFFF:10.0.0.1'), '10.0.0.1');
      expect(TrustedProxy.normalize('::1'), '::1');
      expect(TrustedProxy.normalize('8.8.8.8'), '8.8.8.8');
      TrustedProxy proxy = TrustedProxy(<String>['10.0.0.0/8']);
      expect(proxy.clientIp('10.1.2.3', '::ffff:1.2.3.4'), '1.2.3.4');
    });

    test('ipv6 range and wildcard', () {
      expect(TrustedProxy(<String>['fd00::/8']).trusts('fd12::1'), true);
      expect(TrustedProxy(<String>['fd00::/8']).trusts('fe80::1'), false);
      expect(TrustedProxy(<String>['*']).trusts('9.9.9.9'), true);
    });
  });
}
