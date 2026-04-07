import 'package:url_launcher/url_launcher.dart';

abstract final class ExternalLinkService {
  static Future<bool> openPhone(String phone) {
    return _launchUri(Uri(scheme: 'tel', path: _normalizePhone(phone)));
  }

  static Future<bool> openWhatsApp(String phone) {
    return _launchUri(
        Uri.parse('https://wa.me/${_normalizeWhatsAppPhone(phone)}'));
  }

  static Future<bool> openMap(String url) {
    return _launchUri(Uri.parse(url));
  }

  static Future<bool> _launchUri(Uri uri) async {
    try {
      return launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  static String _normalizePhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (digits.startsWith('+')) {
      return digits;
    }
    if (digits.startsWith('8')) {
      return '+7${digits.substring(1)}';
    }
    if (digits.startsWith('7')) {
      return '+$digits';
    }
    return '+$digits';
  }

  static String _normalizeWhatsAppPhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('8')) {
      return '7${digits.substring(1)}';
    }
    if (digits.startsWith('7')) {
      return digits;
    }
    return '7$digits';
  }
}
