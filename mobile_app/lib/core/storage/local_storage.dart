import 'package:shared_preferences/shared_preferences.dart';

class LocalStorage {
  static const _preferredBranchKey = 'preferred_branch_id';
  static const _localeKey = 'app_locale';
  static const _themeModeKey = 'app_theme_mode';
  static const _pendingPaymentIdKey = 'pending_payment_id';
  static const _ticketQrPayloadPrefix = 'ticket_qr_payload:';

  // ─── Branch ───────────────────────────────────────────────────────────────

  Future<void> savePreferredBranch(String branchId) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_preferredBranchKey, branchId);
  }

  Future<String?> readPreferredBranch() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(_preferredBranchKey);
  }

  // ─── Locale ───────────────────────────────────────────────────────────────

  /// Saves locale language code, e.g. 'ru' or 'kk'.
  Future<void> saveLocale(String languageCode) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_localeKey, languageCode);
  }

  Future<String?> readLocale() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(_localeKey);
  }

  // ─── Theme mode ───────────────────────────────────────────────────────────

  /// Saves 'light' or 'dark'.
  Future<void> saveThemeMode(String mode) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_themeModeKey, mode);
  }

  Future<String?> readThemeMode() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(_themeModeKey);
  }

  Future<void> savePendingPaymentId(String paymentId) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_pendingPaymentIdKey, paymentId);
  }

  Future<String?> readPendingPaymentId() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(_pendingPaymentIdKey);
  }

  Future<void> clearPendingPaymentId() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_pendingPaymentIdKey);
  }

  // ─── Issued ticket QR cache ─────────────────────────────────────────────

  /// Caches the backend-issued QR payload so an already-issued ticket remains
  /// usable while the device is temporarily offline. The backend remains the
  /// source of truth and the detail page removes this value for terminal
  /// ticket statuses.
  Future<void> saveTicketQrPayload(String ticketId, String payload) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_ticketQrKey(ticketId), payload);
  }

  Future<String?> readTicketQrPayload(String ticketId) async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(_ticketQrKey(ticketId));
  }

  Future<void> clearTicketQrPayload(String ticketId) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_ticketQrKey(ticketId));
  }

  String _ticketQrKey(String ticketId) => '$_ticketQrPayloadPrefix$ticketId';
}
