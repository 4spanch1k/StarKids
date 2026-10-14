enum CustomerPassStatus { active, exhausted, expired, cancelled, unknown }

class PassPlan {
  const PassPlan({
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
}

class CustomerPass {
  const CustomerPass({
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

  bool get isActive => status == CustomerPassStatus.active;
}

class PassQuote {
  const PassQuote({
    required this.plan,
    required this.childId,
    required this.branchId,
    required this.amountTenge,
    required this.currency,
  });

  final PassPlan plan;
  final String childId;
  final String branchId;
  final int amountTenge;
  final String currency;
}

class PassPaymentStart {
  const PassPaymentStart({
    required this.paymentId,
    required this.localOrderId,
    required this.externalPaymentId,
    required this.paymentUrl,
    required this.status,
    required this.amountTenge,
  });

  final String paymentId;
  final String localOrderId;
  final String? externalPaymentId;
  final String paymentUrl;
  final String status;
  final int amountTenge;
}

CustomerPassStatus customerPassStatusFromJson(String? raw) {
  return switch (raw?.toLowerCase()) {
    'active' => CustomerPassStatus.active,
    'exhausted' => CustomerPassStatus.exhausted,
    'expired' => CustomerPassStatus.expired,
    'cancelled' || 'canceled' => CustomerPassStatus.cancelled,
    _ => CustomerPassStatus.unknown,
  };
}

String customerPassStatusLabel(CustomerPassStatus status) {
  return switch (status) {
    CustomerPassStatus.active => 'Действует',
    CustomerPassStatus.exhausted => 'Использован',
    CustomerPassStatus.expired => 'Истёк',
    CustomerPassStatus.cancelled => 'Отменён',
    CustomerPassStatus.unknown => 'Статус уточняется',
  };
}
