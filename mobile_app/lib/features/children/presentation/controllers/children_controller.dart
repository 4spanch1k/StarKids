import 'package:flutter/material.dart';

import '../../../../core/utils/result.dart';
import '../../domain/child.dart';
import '../../domain/children_repository.dart';

enum ChildrenStatus { loading, error, empty, success }

enum ChildFormStatus { idle, saving, error }

class ChildrenController extends ChangeNotifier {
  ChildrenController({required ChildrenRepository repository})
      : _repository = repository;

  final ChildrenRepository _repository;

  ChildrenStatus _status = ChildrenStatus.loading;
  List<Child> _children = const [];
  String? _errorMessage;

  ChildFormStatus _formStatus = ChildFormStatus.idle;
  String? _formError;

  ChildrenStatus get status => _status;
  List<Child> get children => _children;
  String? get errorMessage => _errorMessage;

  ChildFormStatus get formStatus => _formStatus;
  String? get formError => _formError;

  bool get isSaving => _formStatus == ChildFormStatus.saving;

  /// Returns children whose birthday is today.
  List<Child> get todaysBirthdays =>
      _children.where((c) => c.isBirthdayToday).toList();

  Future<void> load() async {
    _status = ChildrenStatus.loading;
    _errorMessage = null;
    notifyListeners();

    final result = await _repository.fetchChildren();
    if (result is Success<List<Child>>) {
      _children = result.data;
      _status = _children.isEmpty ? ChildrenStatus.empty : ChildrenStatus.success;
    } else {
      _errorMessage = (result as Failure<List<Child>>).message;
      _status = ChildrenStatus.error;
    }
    notifyListeners();
  }

  Future<bool> addChild({
    required String name,
    required DateTime birthDate,
    required ChildGender gender,
  }) async {
    _formStatus = ChildFormStatus.saving;
    _formError = null;
    notifyListeners();

    final result = await _repository.createChild(
      name: name,
      birthDate: birthDate,
      gender: gender,
    );

    if (result is Success<Child>) {
      _children = [..._children, result.data];
      _status = ChildrenStatus.success;
      _formStatus = ChildFormStatus.idle;
      notifyListeners();
      return true;
    } else {
      _formError = (result as Failure<Child>).message;
      _formStatus = ChildFormStatus.error;
      notifyListeners();
      return false;
    }
  }

  Future<bool> editChild({
    required String childId,
    required String name,
    required DateTime birthDate,
    required ChildGender gender,
  }) async {
    _formStatus = ChildFormStatus.saving;
    _formError = null;
    notifyListeners();

    final result = await _repository.updateChild(
      childId: childId,
      name: name,
      birthDate: birthDate,
      gender: gender,
    );

    if (result is Success<Child>) {
      _children = [
        for (final c in _children)
          if (c.id == childId) result.data else c,
      ];
      _formStatus = ChildFormStatus.idle;
      notifyListeners();
      return true;
    } else {
      _formError = (result as Failure<Child>).message;
      _formStatus = ChildFormStatus.error;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteChild(String childId) async {
    _formStatus = ChildFormStatus.saving;
    _formError = null;
    notifyListeners();

    final result = await _repository.deleteChild(childId);
    if (result is Success<void>) {
      _children = _children.where((c) => c.id != childId).toList();
      _status = _children.isEmpty ? ChildrenStatus.empty : ChildrenStatus.success;
      _formStatus = ChildFormStatus.idle;
      notifyListeners();
      return true;
    } else {
      _formError = (result as Failure<void>).message;
      _formStatus = ChildFormStatus.error;
      notifyListeners();
      return false;
    }
  }

  void clearFormError() {
    if (_formError == null) return;
    _formError = null;
    _formStatus = ChildFormStatus.idle;
    notifyListeners();
  }

  Future<void> retry() => load();
}
