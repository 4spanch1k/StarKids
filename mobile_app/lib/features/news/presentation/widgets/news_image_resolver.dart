import '../../../../app/config/app_environment.dart';

String resolveNewsImageUrl(String rawValue) {
  final normalized = rawValue.trim();
  if (normalized.isEmpty ||
      normalized.startsWith('http://') ||
      normalized.startsWith('https://')) {
    return normalized;
  }

  final baseUri = Uri.parse(AppEnvironment.apiBaseUrl);
  if (normalized.startsWith('/')) {
    return baseUri
        .replace(path: normalized, query: null, fragment: null)
        .toString();
  }

  return baseUri.resolve(normalized).toString();
}
