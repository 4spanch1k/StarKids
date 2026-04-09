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
    final package = await _fetchPackageFromApi(packageId);
    if (package != null) {
      return package;
    }

    return _fallbackRepository.getPackageById(packageId);
  }

  Future<BirthdayPackage?> _fetchPackageFromApi(String packageId) async {
    try {
      final response =
          await _apiClient.getJson('/birthday-packages/$packageId');
      final json = response.jsonBody;

      if (!response.isSuccess || json == null) {
        return null;
      }

      return BirthdayPackageDetailDto.fromJson(json).toDomain();
    } catch (_) {
      return null;
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
          final detailedPackage = await _fetchPackageFromApi(summary.id);
          return detailedPackage ??
              BirthdayPackage(
                id: summary.id,
                name: summary.name,
                priceLabel: summary.priceLabel,
                guestLabel: summary.guestCapacityLabel,
                description: '',
                highlights: const [],
                imagePath: summary.imageUrl?.trim() ?? '',
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
