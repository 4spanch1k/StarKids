import 'package:flutter/material.dart';

import '../../../../core/storage/local_storage.dart';
import '../../data/branch_seed_data.dart';
import '../../domain/branch_option.dart';

class SelectedBranchController extends ChangeNotifier {
  SelectedBranchController({
    required LocalStorage localStorage,
  }) : _localStorage = localStorage;

  final LocalStorage _localStorage;

  String? _storedBranchId;

  String get selectedBranchId => _storedBranchId ?? defaultBranchId;

  BranchOption get selectedBranch => getBranchById(selectedBranchId);

  bool get hasStoredSelection => _storedBranchId != null;

  Future<void> load() async {
    final storedBranchId = await _localStorage.readPreferredBranch();

    if (storedBranchId != null &&
        branchSeedData.any((branch) => branch.id == storedBranchId)) {
      _storedBranchId = storedBranchId;
      notifyListeners();
    }
  }

  Future<void> selectBranch(String branchId) async {
    if (_storedBranchId == branchId) {
      return;
    }

    _storedBranchId = branchId;
    notifyListeners();
    await _localStorage.savePreferredBranch(branchId);
  }
}
