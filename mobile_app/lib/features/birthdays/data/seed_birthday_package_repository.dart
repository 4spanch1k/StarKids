import '../domain/birthday_package.dart';
import '../domain/birthday_package_repository.dart';
import 'birthday_package_seed_data.dart';

class SeedBirthdayPackageRepository implements BirthdayPackageRepository {
  const SeedBirthdayPackageRepository();

  @override
  Future<BirthdayPackage?> getPackageById(String packageId) async {
    return getBirthdayPackageById(packageId);
  }

  @override
  Future<List<BirthdayPackage>> listPackages({
    String? branchId,
  }) async {
    return birthdayPackageSeedData;
  }
}
