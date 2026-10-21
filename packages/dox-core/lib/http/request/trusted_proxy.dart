import 'dart:io';

/// Decides when to believe `X-Forwarded-For` / `X-Forwarded-Proto`.
///
/// Those headers are easy to fake. Dox only reads them when the direct
/// client (the socket peer) is one of the configured proxies.
class TrustedProxy {
  final bool _any;
  final List<_Cidr> _ranges;

  TrustedProxy(List<String> proxies)
    : _any = proxies.contains('*'),
      _ranges = <_Cidr>[
        for (String p in proxies)
          if (p != '*') _Cidr.parse(p),
      ];

  bool get enabled => _any || _ranges.isNotEmpty;

  /// is [ip] one of our proxies?
  bool trusts(String ip) {
    if (_any) return true;
    InternetAddress? address = InternetAddress.tryParse(ip);
    if (address == null) return false;
    for (_Cidr range in _ranges) {
      if (range.contains(address)) return true;
    }
    return false;
  }

  /// real client ip. walk `X-Forwarded-For` from the right and skip our own
  /// proxies, so a fake value added by the client on the left is ignored.
  String clientIp(String remote, String? forwardedFor) {
    if (forwardedFor == null || !trusts(remote)) return remote;
    List<String> hops = forwardedFor.split(',');
    for (int i = hops.length - 1; i >= 0; i--) {
      String hop = hops[i].trim();
      if (hop.isEmpty) continue;
      if (!trusts(hop)) return hop;
      remote = hop;
    }
    return remote;
  }

  /// `https` when a trusted proxy says the client used https
  String scheme(String remote, String? forwardedProto) {
    if (forwardedProto == null || !trusts(remote)) return 'http';
    String proto = forwardedProto.split(',').first.trim().toLowerCase();
    return proto == 'https' ? 'https' : 'http';
  }
}

/// one ip or ip range like `10.0.0.0/8`
class _Cidr {
  final List<int> _bytes;
  final int _bits;

  _Cidr(this._bytes, this._bits);

  factory _Cidr.parse(String value) {
    List<String> parts = value.trim().split('/');
    InternetAddress? address = InternetAddress.tryParse(parts.first);
    if (address == null) {
      throw ArgumentError.value(value, 'trustedProxies', 'not an ip or cidr');
    }
    List<int> bytes = _normalize(address);
    int bits = parts.length > 1 ? int.parse(parts[1]) : bytes.length * 8;
    if (address.type == InternetAddressType.IPv4 && parts.length > 1) {
      bits += 96; // stored as ipv4-mapped ipv6
    }
    return _Cidr(bytes, bits);
  }

  bool contains(InternetAddress address) {
    List<int> other = _normalize(address);
    int bits = _bits;
    for (int i = 0; i < 16 && bits > 0; i++, bits -= 8) {
      int mask = bits >= 8 ? 0xff : (0xff << (8 - bits)) & 0xff;
      if ((other[i] & mask) != (_bytes[i] & mask)) return false;
    }
    return true;
  }

  /// ipv4 and ipv4-mapped ipv6 (`::ffff:1.2.3.4`) compare the same
  static List<int> _normalize(InternetAddress address) {
    List<int> raw = address.rawAddress;
    if (raw.length == 16) return raw;
    return <int>[...List<int>.filled(10, 0), 0xff, 0xff, ...raw];
  }
}
