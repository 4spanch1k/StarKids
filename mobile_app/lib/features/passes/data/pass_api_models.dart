import '../domain/pass.dart';

class PassPlanDto {
  const PassPlanDto({
    required this.id,
    required this.name,
    required this.priceTenge,
    required this.visitLimit,
    required this.validityDays,
    required this.dailyLimit,
    required this.branchId,
    required this.isActive,
  });

  final String id;
  final String name;
  final int priceTenge;
  final int visitLimit;
  final int validityDays;
  final int dailyLimit;
  final String? branchId;
  final bool isActive;

  factory PassPlanDto.fromJson(Map<String, dynamic> json) => PassPlanDto(
        id: '${json['id'] ?? ''}',
        name: '${json['name'] ?? ''}',
        priceTenge: (json['priceTenge'] as num?)?.toInt() ?? 0,
        visitLimit: (json['visitLimit'] as num?)?.toInt() ?? 0,
        validityDays: (json['validityDays'] as num?)?.toInt() ?? 0,
        dailyLimit: (json['dailyLimit'] as num?)?.toInt() ?? 1,
        branchId: json['branchId'] as String?,
        isActive: json['isActive'] as bool? ?? true,
      );

  PassPlan toDomain() => PassPlan(
        id: id,
        name: name,
        priceTenge: priceTenge,
        visitLimit: visitLimit,
        validityDays: validityDays,
        dailyLimit: dailyLimit,
        branchId: branchId,
        isActive: isActive,
      );
}

class CustomerPassDto {
  const CustomerPassDto({
    required this.id,
    required this.childId,
    required this.childName,
    required this.passPlanId,
    required this.planName,
    required this.priceTenge,
    required this.visitLimit,
    required this.validityDays,
    required this.dailyLimit,
    required this.branchId,
    required this.activatedAt,
    required this.expiresAt,
    required this.remainingVisits,
    required this.status,
  });

  final String id;
  final String childId;
  final String childName;
  final String passPlanId;
  final String planName;
  final int priceTenge;
  final int visitLimit;
  final int validityDays;
  final int dailyLimit;
  final String? branchId;
  final DateTime activatedAt;
  final DateTime expiresAt;
  final int remainingVisits;
  final CustomerPassStatus status;

  factory CustomerPassDto.fromJson(Map<String, dynamic> json) =>
      CustomerPassDto(
        id: '${json['id'] ?? ''}',
        childId: '${json['childId'] ?? ''}',
        childName: '${json['childName'] ?? ''}',
        passPlanId: '${json['passPlanId'] ?? ''}',
        planName: '${json['planName'] ?? ''}',
        priceTenge: (json['priceTenge'] as num?)?.toInt() ?? 0,
        visitLimit: (json['visitLimit'] as num?)?.toInt() ?? 0,
        validityDays: (json['validityDays'] as num?)?.toInt() ?? 0,
        dailyLimit: (json['dailyLimit'] as num?)?.toInt() ?? 1,
        branchId: json['branchId'] as String?,
        activatedAt:
            DateTime.tryParse('${json['activatedAt']}') ?? DateTime.now(),
        expiresAt: DateTime.tryParse('${json['expiresAt']}') ?? DateTime.now(),
        remainingVisits: (json['remainingVisits'] as num?)?.toInt() ?? 0,
        status: customerPassStatusFromJson(json['status'] as String?),
      );

  CustomerPass toDomain() => CustomerPass(
        id: id,
        childId: childId,
        childName: childName,
        passPlanId: passPlanId,
        planName: planName,
        priceTenge: priceTenge,
        visitLimit: visitLimit,
        validityDays: validityDays,
        dailyLimit: dailyLimit,
        branchId: branchId,
        activatedAt: activatedAt,
        expiresAt: expiresAt,
        remainingVisits: remainingVisits,
        status: status,
      );
}

class PassQuoteDto {
  const PassQuoteDto({
    required this.plan,
    required this.childId,
    required this.branchId,
    required this.amountTenge,
    required this.currency,
  });

  final PassPlanDto plan;
  final String childId;
  final String branchId;
  final int amountTenge;
  final String currency;

  factory PassQuoteDto.fromJson(Map<String, dynamic> json) => PassQuoteDto(
        plan: PassPlanDto.fromJson(
          json['passPlan'] as Map<String, dynamic>? ?? const {},
        ),
        childId: '${json['childId'] ?? ''}',
        branchId: '${json['branchId'] ?? ''}',
        amountTenge: (json['amountTenge'] as num?)?.toInt() ?? 0,
        currency: json['currency'] as String? ?? 'KZT',
      );

  PassQuote toDomain() => PassQuote(
        plan: plan.toDomain(),
        childId: childId,
        branchId: branchId,
        amountTenge: amountTenge,
        currency: currency,
      );
}

PassPaymentStart passPaymentStartFromJson(Map<String, dynamic> json) =>
    PassPaymentStart(
      paymentId: '${json['paymentId'] ?? ''}',
      localOrderId: '${json['localOrderId'] ?? ''}',
      externalPaymentId: json['externalPaymentId'] as String?,
      paymentUrl: '${json['paymentUrl'] ?? ''}',
      status: json['status'] as String? ?? 'pending',
      // Pass init reuses FreedomPaymentInitResponse. Its authoritative
      // amount fields are grossAmountTenge/cashAmountTenge; there is no
      // amountTenge field on that response.
      amountTenge: (json['cashAmountTenge'] as num?)?.toInt() ??
          (json['grossAmountTenge'] as num?)?.toInt() ??
          0,
    );
