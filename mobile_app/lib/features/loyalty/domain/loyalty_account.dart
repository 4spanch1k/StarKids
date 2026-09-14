class LoyaltyAccount {
  const LoyaltyAccount({
    required this.balance,
    required this.reservedBalance,
    required this.availableBalance,
    required this.lifetimeEarned,
    required this.lifetimeSpent,
  });

  final int balance;
  final int reservedBalance;
  final int availableBalance;
  final int lifetimeEarned;
  final int lifetimeSpent;

  factory LoyaltyAccount.fromJson(Map<String, dynamic> json) => LoyaltyAccount(
        balance: (json['balance'] as num?)?.toInt() ?? 0,
        reservedBalance: (json['reservedBalance'] as num?)?.toInt() ?? 0,
        availableBalance: (json['availableBalance'] as num?)?.toInt() ?? 0,
        lifetimeEarned: (json['lifetimeEarned'] as num?)?.toInt() ?? 0,
        lifetimeSpent: (json['lifetimeSpent'] as num?)?.toInt() ?? 0,
      );
}
