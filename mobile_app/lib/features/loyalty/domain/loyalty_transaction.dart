class LoyaltyTransaction {
  const LoyaltyTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.balanceDelta,
    required this.reservedDelta,
    required this.sourceType,
    required this.sourceId,
    required this.status,
    required this.description,
    required this.createdAt,
  });

  final String id;
  final String type;
  final int amount;
  final int balanceDelta;
  final int reservedDelta;
  final String sourceType;
  final String sourceId;
  final String status;
  final String? description;
  final DateTime createdAt;

  factory LoyaltyTransaction.fromJson(Map<String, dynamic> json) => LoyaltyTransaction(
        id: json['id'] as String,
        type: json['type'] as String,
        amount: (json['amount'] as num).toInt(),
        balanceDelta: (json['balanceDelta'] as num).toInt(),
        reservedDelta: (json['reservedDelta'] as num).toInt(),
        sourceType: json['sourceType'] as String,
        sourceId: json['sourceId'] as String,
        status: json['status'] as String,
        description: json['description'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}
