import 'package:dox_core/dox_core.dart';
import 'package:test/test.dart';

void main() {
  test('IPv4 stays as it is', () {
    expect(RateLimit.ipBucket('1.2.3.4'), '1.2.3.4');
  });

  test('IPv6 gives its /64 prefix', () {
    expect(RateLimit.ipBucket('2001:db8:1:2:aaaa::1'), '2001:db8:1:2::/64');
    expect(
      RateLimit.ipBucket('2001:0db8:0001:0002:ffff:ffff:ffff:ffff'),
      '2001:db8:1:2::/64',
    );
    expect(RateLimit.ipBucket('::1'), '0:0:0:0::/64');
    expect(RateLimit.ipBucket('fe80::1%en0'), 'fe80:0:0:0::/64');
  });

  test('IPv4-mapped IPv6 counts as the IPv4 address', () {
    expect(RateLimit.ipBucket('::ffff:1.2.3.4'), '1.2.3.4');
    expect(RateLimit.ipBucket('::ffff:0102:0304'), '1.2.3.4');
  });

  test('a value that is not an ip stays as it is', () {
    expect(RateLimit.ipBucket('unknown'), 'unknown');
    expect(RateLimit.ipBucket('not:an:ip'), 'not:an:ip');
  });
}
