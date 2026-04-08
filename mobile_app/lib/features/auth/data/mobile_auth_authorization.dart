import '../domain/mobile_auth_session.dart';

Map<String, String> buildMobileAuthAuthorizationHeader(
  MobileAuthSession session,
) {
  final normalizedTokenType = _capitalizeTokenType(session.tokenType);
  return {
    'Authorization': '$normalizedTokenType ${session.accessToken}',
  };
}

String _capitalizeTokenType(String value) {
  if (value.isEmpty) {
    return 'Bearer';
  }

  return '${value[0].toUpperCase()}${value.substring(1)}';
}
