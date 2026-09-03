import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/api_news_repository.dart';
import '../../domain/news_item.dart';
import '../../domain/news_repository.dart';

enum NewsFeedKind {
  promotions,
  notifications,
}

class NewsFeedController extends ChangeNotifier {
  NewsFeedController({
    required NewsRepository repository,
    this.feedKind = NewsFeedKind.promotions,
    int pageSize = 10,
    Duration cacheTtl = const Duration(minutes: 3),
  })  : _repository = repository,
        _pageSize = pageSize,
        _cacheTtl = cacheTtl;

  final NewsRepository _repository;
  final int _pageSize;
  final Duration _cacheTtl;
  final NewsFeedKind feedKind;
  static final Map<NewsFeedKind, _NewsFeedCacheEntry> _cache =
      <NewsFeedKind, _NewsFeedCacheEntry>{};

  List<NewsItem> _items = const [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _isBootstrapped = false;
  bool _hasMore = true;
  bool _isOffline = false;
  String? _errorMessage;
  bool _isDisposed = false;

  List<NewsItem> get items => _items;

  bool get isLoading => _isLoading;

  bool get isLoadingMore => _isLoadingMore;

  bool get hasMore => _hasMore;

  bool get isOffline => _isOffline;

  String? get errorMessage => _errorMessage;

  static void clearCache() {
    _cache.clear();
  }

  @override
  void notifyListeners() {
    if (!_isDisposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  Future<void> bootstrap() async {
    if (_isBootstrapped) {
      return;
    }

    _isBootstrapped = true;

    final validCache = _cache[feedKind];
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
      final nextItems = await _loadPage(offset: _items.length);
      _items = _deduplicateItems(<NewsItem>[
        ..._items,
        ...nextItems,
      ]);
      _hasMore = nextItems.length == _pageSize;
      _isOffline = false;
      _errorMessage = null;
      _writeCache();
    } on NewsNetworkException {
      _isOffline = true;
      _errorMessage = 'Нет соединения\nПоказаны последние данные';
    } catch (_) {
      _errorMessage = 'Не удалось догрузить новости.';
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> trackClick(String newsId) async {
    try {
      await _repository.trackNewsEvent(
        newsId: newsId,
        eventType: NewsEventType.click,
      );
    } catch (_) {
      // Analytics should never block navigation.
    }
  }

  Future<List<NewsItem>> _loadPage({
    required int offset,
  }) {
    switch (feedKind) {
      case NewsFeedKind.promotions:
        return _repository.listPromotedNews(
          limit: _pageSize,
          offset: offset,
        );
      case NewsFeedKind.notifications:
        return _repository.listNotificationHistory(
          limit: _pageSize,
          offset: offset,
        );
    }
  }

  Future<void> _refresh({
    required bool useValidCache,
  }) async {
    if (_isLoading || _isLoadingMore) {
      return;
    }

    final validCache = _cache[feedKind];
    if (useValidCache && validCache != null && validCache.isValid(_cacheTtl)) {
      _restoreCache(validCache);
      return;
    }

    _isLoading = true;
    _isOffline = false;
    _errorMessage = null;
    notifyListeners();

    try {
      final nextItems = await _loadPage(offset: 0);
      _items = _deduplicateItems(nextItems);
      _hasMore = nextItems.length == _pageSize;
      _errorMessage = null;
      _writeCache();
    } on NewsNetworkException {
      _handleNetworkFailure();
    } catch (_) {
      _errorMessage = _items.isEmpty
          ? 'Не удалось загрузить новости.'
          : 'Не удалось обновить новости.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _handleNetworkFailure() {
    final staleCache = _cache[feedKind];
    if (staleCache != null) {
      _restoreCache(staleCache);
    }

    if (_items.isEmpty) {
      _hasMore = false;
    }
    _isOffline = true;
    _errorMessage = 'Нет соединения\nПоказаны последние данные';
  }

  void _restoreCache(_NewsFeedCacheEntry entry) {
    _items = entry.items;
    _hasMore = entry.hasMore;
    _isOffline = false;
    _errorMessage = null;
    notifyListeners();
  }

  void _writeCache() {
    _cache[feedKind] = _NewsFeedCacheEntry(
      items: List<NewsItem>.unmodifiable(_items),
      hasMore: _hasMore,
      storedAt: DateTime.now(),
    );
  }

  List<NewsItem> _deduplicateItems(List<NewsItem> items) {
    final byId = <String, NewsItem>{};
    for (final item in items) {
      byId[item.id] = item;
    }
    return byId.values.toList(growable: false);
  }
}

class _NewsFeedCacheEntry {
  const _NewsFeedCacheEntry({
    required this.items,
    required this.hasMore,
    required this.storedAt,
  });

  final List<NewsItem> items;
  final bool hasMore;
  final DateTime storedAt;

  bool isValid(Duration ttl) {
    return DateTime.now().difference(storedAt) <= ttl;
  }
}
