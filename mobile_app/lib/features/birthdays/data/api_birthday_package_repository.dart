import 'dart:async';

import '../../../core/api/api_client.dart';
import '../domain/birthday_package.dart';
import '../domain/birthday_package_repository.dart';
import 'birthday_package_api_models.dart';

class ApiBirthdayPackageRepository implements BirthdayPackageRepository {
  ApiBirthdayPackageRepository({
    required ApiClient apiClient,
  }) : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<BirthdayPackage?> getPackageById(String packageId) async {
    final package = await _fetchPackageFromApi(packageId);
    return package;
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
    final suffix = branchId == null
        ? ''
        : '?branch_id=${Uri.encodeQueryComponent(branchId)}';
    final response = await _apiClient.getJson('/birthday-packages$suffix');
    final jsonList = response.jsonListBody;

    if (!response.isSuccess || jsonList == null) {
      throw StateError('Birthday packages are not available');
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
  }
}
