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
    final availableBranches = await _listAvailableBranches();
    if (availableBranches.isNotEmpty) {
      BranchOption? matchingBranch;
      for (final branch in availableBranches) {
        if (branch.id == storedBranchId) {
          matchingBranch = branch;
          break;
        }
      }

      _selectedBranch = matchingBranch ?? availableBranches.first;

      if (storedBranchId != _selectedBranch.id) {
        await _localStorage.savePreferredBranch(_selectedBranch.id);
      }
    } else {
      final resolvedBranch = await _resolveBranch(storedBranchId ?? defaultBranchId);
      _selectedBranch = resolvedBranch;

      if (storedBranchId != _selectedBranch.id) {
        await _localStorage.savePreferredBranch(_selectedBranch.id);
      }
    }

    notifyListeners();
  }

  Future<void> selectBranch(
    String branchId, {
    BranchOption? selectedBranch,
  }) async {
    _hasStoredSelection = true;
    _applySelectedBranch(selectedBranch ?? await _resolveBranch(branchId));
    await _localStorage.savePreferredBranch(_selectedBranch.id);
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
      try {
        return getBranchById(branchId);
      } catch (_) {
        return getBranchById(defaultBranchId);
      }
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

  Future<List<BranchOption>> _listAvailableBranches() async {
    try {
      return await _branchRepository.listBranches();
    } catch (_) {
      return const <BranchOption>[];
    }
  }
}
