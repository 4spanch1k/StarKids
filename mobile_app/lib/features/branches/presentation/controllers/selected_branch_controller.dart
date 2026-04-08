import 'package:flutter/material.dart';

import '../../../../core/storage/local_storage.dart';
import '../../data/branch_seed_data.dart';
import '../../domain/branch_option.dart';
import '../../domain/branch_repository.dart';

class SelectedBranchController extends ChangeNotifier {
  SelectedBranchController({
    required LocalStorage localStorage,
    required BranchRepository branchRepository,
  })  : _localStorage = localStorage,
        _branchRepository = branchRepository;

  final LocalStorage _localStorage;
  final BranchRepository _branchRepository;

  bool _hasStoredSelection = false;
  BranchOption _selectedBranch = getBranchById(defaultBranchId);

  String get selectedBranchId => _selectedBranch.id;

  BranchOption get selectedBranch => _selectedBranch;

  bool get hasStoredSelection => _hasStoredSelection;

  Future<void> load() async {
    final storedBranchId = await _localStorage.readPreferredBranch();
    _hasStoredSelection = storedBranchId != null;
    _selectedBranch = await _resolveBranch(storedBranchId ?? defaultBranchId);
    notifyListeners();
  }

  Future<void> selectBranch(
    String branchId, {
    BranchOption? selectedBranch,
  }) async {
    if (_selectedBranch.id == branchId) {
      return;
    }

    _hasStoredSelection = true;
    _selectedBranch = selectedBranch ?? await _resolveBranch(branchId);
    notifyListeners();
    await _localStorage.savePreferredBranch(branchId);
  }

  Future<BranchOption> _resolveBranch(String branchId) async {
    try {
      return await _branchRepository.getBranch(branchId);
    } catch (_) {
      return getBranchById(branchId);
    }
  }
}
