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
      if (selectedBranch != null) {
        _applySelectedBranch(selectedBranch);
      }
      return;
    }

    _hasStoredSelection = true;
    _selectedBranch = selectedBranch ?? await _resolveBranch(branchId);
    notifyListeners();
    await _localStorage.savePreferredBranch(branchId);
  }

  Future<void> refreshSelectedBranch() async {
    final refreshedBranch = await _resolveBranch(_selectedBranch.id);
    _applySelectedBranch(refreshedBranch);
  }

  void syncSelectedBranch(BranchOption branch) {
    if (_selectedBranch.id != branch.id) {
      return;
    }

    _applySelectedBranch(branch);
  }

  Future<BranchOption> _resolveBranch(String branchId) async {
    try {
      return await _branchRepository.getBranch(branchId);
    } catch (_) {
      return getBranchById(branchId);
    }
  }

  void _applySelectedBranch(BranchOption branch) {
    if (_isSameBranch(_selectedBranch, branch)) {
      return;
    }

    _selectedBranch = branch;
    notifyListeners();
  }

  bool _isSameBranch(BranchOption left, BranchOption right) {
    return left.id == right.id &&
        left.name == right.name &&
        left.address == right.address &&
        left.workingHours == right.workingHours &&
        left.description == right.description &&
        left.phone == right.phone &&
        left.whatsAppPhone == right.whatsAppPhone &&
        left.heroImagePath == right.heroImagePath &&
        _listEquals(left.galleryImagePaths, right.galleryImagePaths) &&
        _listEquals(left.facilities, right.facilities) &&
        left.shortLabel == right.shortLabel;
  }

  bool _listEquals(List<String> left, List<String> right) {
    if (left.length != right.length) {
      return false;
    }

    for (var index = 0; index < left.length; index += 1) {
      if (left[index] != right[index]) {
        return false;
      }
    }

    return true;
  }
}
