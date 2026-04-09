import 'birthday_package.dart';

abstract interface class BirthdayPackageRepository {
  Future<List<BirthdayPackage>> listPackages({
    String? branchId,
  });

  Future<BirthdayPackage?> getPackageById(String packageId);
}
