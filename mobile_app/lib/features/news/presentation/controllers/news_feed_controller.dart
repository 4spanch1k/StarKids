import 'package:flutter/foundation.dart';

import '../../domain/news_item.dart';
import '../../domain/news_repository.dart';

class NewsFeedController extends ChangeNotifier {
  NewsFeedController({
    required NewsRepository repository,
  }) : _repository = repository;

  final NewsRepository _repository;

  List<NewsItem> _items = const [];
  bool _isLoading = false;
  bool _isBootstrapped = false;
  String? _errorMessage;

  List<NewsItem> get items => _items;

  bool get isLoading => _isLoading;

  String? get errorMessage => _errorMessage;

  Future<void> bootstrap() async {
    if (_isBootstrapped) {
      return;
    }

    _isBootstrapped = true;
    await refresh();
  }

  Future<void> refresh() async {
    if (_isLoading) {
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _items = await _repository.listNews();
      _errorMessage = null;
    } catch (_) {
      _errorMessage = 'Не удалось загрузить новости.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
