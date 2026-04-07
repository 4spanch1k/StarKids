import 'dart:async';

import '../../../core/api/api_client.dart';
import '../domain/birthday_package.dart';
import '../domain/birthday_package_repository.dart';
import 'birthday_package_api_models.dart';
import 'seed_birthday_package_repository.dart';

class ApiBirthdayPackageRepository implements BirthdayPackageRepository {
  ApiBirthdayPackageRepository({
    required ApiClient apiClient,
    BirthdayPackageRepository? fallbackRepository,
  })  : _apiClient = apiClient,
        _fallbackRepository =
            fallbackRepository ?? const SeedBirthdayPackageRepository();

  final ApiClient _apiClient;
  final BirthdayPackageRepository _fallbackRepository;

  @override
  Future<BirthdayPackage?> getPackageById(String packageId) async {
    try {
      final response =
          await _apiClient.getJson('/birthday-packages/$packageId');
      final json = response.jsonBody;

      if (!response.isSuccess || json == null) {
        return _fallbackRepository.getPackageById(packageId);
      }

      return BirthdayPackageDetailDto.fromJson(json).toDomain();
    } catch (_) {
      return _fallbackRepository.getPackageById(packageId);
    }
  }

  @override
  Future<List<BirthdayPackage>> listPackages({
    String? branchId,
  }) async {
    try {
      final suffix = branchId == null
          ? ''
          : '?branch_id=${Uri.encodeQueryComponent(branchId)}';
      final response = await _apiClient.getJson('/birthday-packages$suffix');
      final jsonList = response.jsonListBody;

      if (!response.isSuccess || jsonList == null) {
        return _fallbackRepository.listPackages(branchId: branchId);
      }

      final summaries = jsonList
          .whereType<Map<String, dynamic>>()
          .map(BirthdayPackageSummaryDto.fromJson)
          .toList();

      final details = await Future.wait(
        summaries.map((summary) async {
          final detailedPackage = await getPackageById(summary.id);
          return detailedPackage ??
              BirthdayPackage(
                id: summary.id,
                name: summary.name,
                priceLabel: summary.priceLabel,
                guestLabel: summary.guestCapacityLabel,
                description: '',
                highlights: const [],
                imagePath: summary.imageUrl?.trim().isNotEmpty == true
                    ? summary.imageUrl!
                    : 'assets/images/birthday_hero.jpg',
                isFeatured: summary.isFeatured,
              );
        }),
      );

      return details;
    } catch (_) {
      return _fallbackRepository.listPackages(branchId: branchId);
    }
  }
}
