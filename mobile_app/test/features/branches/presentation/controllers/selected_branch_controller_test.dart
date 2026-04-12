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

  test(
    'selecting the default branch still persists the branch choice',
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
    },
  );

  test(
    'load replaces stale stored branch with a real backend branch',
    () async {
      SharedPreferences.setMockInitialValues({
        'preferred_branch_id': defaultBranchId,
      });

      final backendBranch = BranchOption(
        id: 'branch-main',
        name: 'Star Kids Main',
        shortLabel: 'Main',
        address: 'Al-Farabi 10',
        workingHours: '10:00 - 22:00',
        description: 'Главный филиал',
        phone: '+77070000000',
        whatsAppPhone: '+77070000000',
        heroImagePath: '',
        galleryImagePaths: const [],
        facilities: const ['Кафе'],
      );
      final controller = SelectedBranchController(
        localStorage: LocalStorage(),
        branchRepository: _FakeBranchRepository(branches: [backendBranch]),
      );

      await controller.load();

      expect(controller.selectedBranchId, backendBranch.id);

      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getString('preferred_branch_id'), backendBranch.id);
    },
  );
}

class _FakeBranchRepository implements BranchRepository {
  _FakeBranchRepository({List<BranchOption>? branches})
      : _branches = branches ?? branchSeedData;

  final List<BranchOption> _branches;

  @override
  Future<BranchOption> getBranch(String branchIdOrSlug) async {
    return _branches.firstWhere(
      (branch) => branch.id == branchIdOrSlug,
      orElse: () => getBranchById(branchIdOrSlug),
    );
  }

  @override
  Future<List<BranchOption>> listBranches() async {
    return _branches;
  }
}
