import 'package:flutter/foundation.dart';

import '../../data/api_notification_history_repository.dart';
import '../../domain/app_notification.dart';
import '../../domain/notification_history_repository.dart';

class NotificationHistoryController extends ChangeNotifier {
  NotificationHistoryController({
    required NotificationHistoryRepository repository,
    int pageSize = 10,
    Duration cacheTtl = const Duration(minutes: 3),
  })  : _repository = repository,
        _pageSize = pageSize,
        _cacheTtl = cacheTtl;

  final NotificationHistoryRepository _repository;
  final int _pageSize;
  final Duration _cacheTtl;

  static _NotificationCacheEntry? _cache;

  List<AppNotification> _items = const [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _isBootstrapped = false;
  bool _hasMore = true;
  bool _isOffline = false;
  String? _errorMessage;

  List<AppNotification> get items => _items;

  bool get isLoading => _isLoading;

  bool get isLoadingMore => _isLoadingMore;

  bool get hasMore => _hasMore;

  bool get isOffline => _isOffline;

  String? get errorMessage => _errorMessage;

  static void clearCache() {
    _cache = null;
  }

  Future<void> bootstrap() async {
    if (_isBootstrapped) {
      return;
    }

    _isBootstrapped = true;

    final validCache = _cache;
    if (validCache != null && validCache.isValid(_cacheTtl)) {
      _restoreCache(validCache);
      return;
    }

    await forceRefresh();
  }

  Future<void> refresh() async {
    await _refresh(useValidCache: true);
  }

  Future<void> forceRefresh() async {
    await _refresh(useValidCache: false);
  }

  Future<void> loadMore() async {
    if (_isLoading || _isLoadingMore || !_hasMore) {
      return;
    }

    _isLoadingMore = true;
    notifyListeners();

    try {
      final nextItems = await _repository.listNotifications(
        limit: _pageSize,
        offset: _items.length,
      );
      _items = _deduplicateItems(<AppNotification>[
        ..._items,
        ...nextItems,
      ]);
      _hasMore = nextItems.length == _pageSize;
      _isOffline = false;
      _errorMessage = null;
      _writeCache();
    } on NotificationNetworkException {
      _isOffline = true;
      _errorMessage = 'Нет соединения\nПоказаны последние данные';
    } catch (_) {
      _errorMessage = 'Не удалось догрузить уведомления.';
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> _refresh({
    required bool useValidCache,
  }) async {
    if (_isLoading || _isLoadingMore) {
      return;
    }

    final validCache = _cache;
    if (useValidCache && validCache != null && validCache.isValid(_cacheTtl)) {
      _restoreCache(validCache);
      return;
    }

    _isLoading = true;
    _isOffline = false;
    _errorMessage = null;
    notifyListeners();

    try {
      final nextItems = await _repository.listNotifications(
        limit: _pageSize,
        offset: 0,
      );
      _items = _deduplicateItems(nextItems);
      _hasMore = nextItems.length == _pageSize;
      _errorMessage = null;
      _writeCache();
    } on NotificationNetworkException {
      _handleNetworkFailure();
    } catch (_) {
      _errorMessage = _items.isEmpty
          ? 'Не удалось загрузить уведомления.'
          : 'Не удалось обновить уведомления.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _handleNetworkFailure() {
    final staleCache = _cache;
    if (staleCache != null) {
      _restoreCache(staleCache);
    }

    if (_items.isEmpty) {
      _hasMore = false;
    }
    _isOffline = true;
    _errorMessage = 'Нет соединения\nПоказаны последние данные';
  }

  void _restoreCache(_NotificationCacheEntry entry) {
    _items = entry.items;
    _hasMore = entry.hasMore;
    _isOffline = false;
    _errorMessage = null;
    notifyListeners();
  }

  void _writeCache() {
    _cache = _NotificationCacheEntry(
      items: List<AppNotification>.unmodifiable(_items),
      hasMore: _hasMore,
      storedAt: DateTime.now(),
    );
  }

  List<AppNotification> _deduplicateItems(List<AppNotification> items) {
    final byId = <String, AppNotification>{};
    for (final item in items) {
      byId[item.id] = item;
    }
    return byId.values.toList(growable: false);
  }
}

class _NotificationCacheEntry {
  const _NotificationCacheEntry({
    required this.items,
    required this.hasMore,
    required this.storedAt,
  });

  final List<AppNotification> items;
  final bool hasMore;
  final DateTime storedAt;

  bool isValid(Duration ttl) {
    return DateTime.now().difference(storedAt) <= ttl;
  }
}
