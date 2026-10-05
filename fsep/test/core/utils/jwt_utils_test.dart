import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fsep/core/utils/jwt_utils.dart';

String _makeToken(Map<String, dynamic> payload) {
  String encode(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  final header = encode({'alg': 'none', 'typ': 'JWT'});
  final body = encode(payload);
  return '$header.$body.signature';
}

void main() {
  test('returns false for a token with a future exp claim', () {
    final token = _makeToken({
      'exp': DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
          1000,
    });

    expect(JwtUtils.isExpired(token), isFalse);
  });

  test('returns true for a token with a past exp claim', () {
    final token = _makeToken({
      'exp':
          DateTime.now().subtract(const Duration(hours: 1)).millisecondsSinceEpoch ~/
              1000,
    });

    expect(JwtUtils.isExpired(token), isTrue);
  });

  test('returns true for a malformed token', () {
    expect(JwtUtils.isExpired('not-a-jwt'), isTrue);
  });

  test('returns true when the exp claim is missing', () {
    final token = _makeToken({'sub': 'user-1'});

    expect(JwtUtils.isExpired(token), isTrue);
  });
}
