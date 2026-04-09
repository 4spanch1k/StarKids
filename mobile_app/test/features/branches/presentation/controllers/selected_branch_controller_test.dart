import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:star_kids_mobile/core/storage/local_storage.dart';
import 'package:star_kids_mobile/features/branches/data/branch_seed_data.dart';
import 'package:star_kids_mobile/features/branches/domain/branch_option.dart';
import 'package:star_kids_mobile/features/branches/domain/branch_repository.dart';
import 'package:star_kids_mobile/features/branches/presentation/controllers/selected_branch_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('selecting the default branch still persists the branch choice',
      () async {
    final controller = SelectedBranchController(
      localStorage: LocalStorage(),
      branchRepository: _FakeBranchRepository(),
    );

    await controller.selectBranch(defaultBranchId);

    expect(controller.selectedBranchId, defaultBranchId);
    expect(controller.hasStoredSelection, isTrue);

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('preferred_branch_id'), defaultBranchId);
  });
}

class _FakeBranchRepository implements BranchRepository {
  @override
  Future<BranchOption> getBranch(String branchIdOrSlug) async {
    return getBranchById(branchIdOrSlug);
  }

  @override
  Future<List<BranchOption>> listBranches() async {
    return branchSeedData;
  }
}
