import '../domain/request_history_item.dart';
import '../../requests/domain/request_status.dart';
import '../../requests/domain/request_type.dart';

class RequestHistoryListDto {
  const RequestHistoryListDto({
    required this.items,
    required this.total,
  });

  final List<RequestHistoryItemDto> items;
  final int total;

  factory RequestHistoryListDto.fromJson(Map<String, dynamic> json) {
    return RequestHistoryListDto(
      items: (json['items'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(RequestHistoryItemDto.fromJson)
          .toList(growable: false),
      total: (json['total'] as num?)?.toInt() ?? 0,
    );
  }
}

class RequestHistoryItemDto {
  const RequestHistoryItemDto({
    required this.id,
    required this.type,
    required this.status,
    required this.createdAt,
    required this.requestedDate,
    required this.guestCount,
    required this.notes,
    required this.branch,
    required this.package,
  });

  final String id;
  final String type;
  final String status;
  final DateTime createdAt;
  final DateTime? requestedDate;
  final int? guestCount;
  final String? notes;
  final RequestHistoryBranchSummaryDto? branch;
  final RequestHistoryPackageSummaryDto? package;

  factory RequestHistoryItemDto.fromJson(Map<String, dynamic> json) {
    return RequestHistoryItemDto(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? '',
      status: json['status'] as String? ?? '',
      createdAt: DateTime.parse(
        json['createdAt'] as String? ??
            DateTime.fromMillisecondsSinceEpoch(0).toUtc().toIso8601String(),
      ),
      requestedDate: _parseDate(json['requestedDate'] as String?),
      guestCount: (json['guestCount'] as num?)?.toInt(),
      notes: json['notes'] as String?,
      branch: _parseBranch(json['branch']),
      package: _parsePackage(json['package']),
    );
  }

  RequestHistoryItem toDomain() {
    return RequestHistoryItem(
      id: id,
      type: RequestType.fromApi(type),
      status: RequestStatus.fromApi(status),
      createdAt: createdAt,
      requestedDate: requestedDate,
      guestCount: guestCount,
      notes: notes,
      branch: branch?.toDomain(),
      package: package?.toDomain(),
    );
  }

  static DateTime? _parseDate(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }

    return DateTime.tryParse(value);
  }

  static RequestHistoryBranchSummaryDto? _parseBranch(Object? value) {
    if (value is! Map<String, dynamic>) {
      return null;
    }

    return RequestHistoryBranchSummaryDto.fromJson(value);
  }

  static RequestHistoryPackageSummaryDto? _parsePackage(Object? value) {
    if (value is! Map<String, dynamic>) {
      return null;
    }

    return RequestHistoryPackageSummaryDto.fromJson(value);
  }
}

class RequestHistoryBranchSummaryDto {
  const RequestHistoryBranchSummaryDto({
    required this.id,
    required this.name,
    required this.shortLabel,
  });

  final String id;
  final String name;
  final String shortLabel;

  factory RequestHistoryBranchSummaryDto.fromJson(Map<String, dynamic> json) {
    return RequestHistoryBranchSummaryDto(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      shortLabel: json['shortLabel'] as String? ?? '',
    );
  }

  RequestHistoryBranchSummary toDomain() {
    return RequestHistoryBranchSummary(
      id: id,
      name: name,
      shortLabel: shortLabel,
    );
  }
}

class RequestHistoryPackageSummaryDto {
  const RequestHistoryPackageSummaryDto({
    required this.id,
    required this.name,
  });

  final String id;
  final String name;

  factory RequestHistoryPackageSummaryDto.fromJson(Map<String, dynamic> json) {
    return RequestHistoryPackageSummaryDto(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
    );
  }

  RequestHistoryPackageSummary toDomain() {
    return RequestHistoryPackageSummary(
      id: id,
      name: name,
    );
  }
}
