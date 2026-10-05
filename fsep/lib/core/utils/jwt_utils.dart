import 'dart:convert';

/// Minimal JWT helpers. Only reads the standard `exp` claim (RFC 7519) to
/// determine local session validity — this does not verify the token's
/// signature, since that responsibility belongs to the server on every
/// authenticated request. Not a general JWT library; deliberately kept to
/// the one thing Splash's session check needs.
class JwtUtils {
  JwtUtils._();

  static bool isExpired(String token) {
    final parts = token.split('.');
    if (parts.length != 3) {
      return true;
    }

    try {
      final normalized = base64Url.normalize(parts[1]);
      final payload =
          jsonDecode(utf8.decode(base64Url.decode(normalized)))
              as Map<String, dynamic>;
      final exp = payload['exp'];
      if (exp is! int) {
        return true;
      }
      final expiry = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      return DateTime.now().isAfter(expiry);
    } catch (_) {
      return true;
    }
  }
}
