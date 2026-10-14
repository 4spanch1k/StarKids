import '../domain/loyalty_transaction.dart';

class LoyaltyTransactionPresentation {
  const LoyaltyTransactionPresentation({
    required this.title,
    required this.amountLabel,
    required this.isPositive,
    this.subtitle,
  });

  final String title;
  final String amountLabel;
  final bool isPositive;
  final String? subtitle;
}

LoyaltyTransactionPresentation presentLoyaltyTransaction(
  LoyaltyTransaction transaction,
) {
  final type = transaction.type.toLowerCase();
  if (type == 'reserve' || type == 'release') {
    return const LoyaltyTransactionPresentation(
      title: 'Внутренняя операция',
      amountLabel: '',
      isPositive: false,
    );
  }
  if (type == 'earn') {
    return LoyaltyTransactionPresentation(
      title: 'Начисление бонусов',
      amountLabel: '+${_formatBonus(transaction.amount)}',
      isPositive: true,
      subtitle: transaction.description,
    );
  }
  if (type == 'spend' || type == 'capture') {
    return LoyaltyTransactionPresentation(
      title: 'Использование бонусов',
      amountLabel: '-${_formatBonus(transaction.amount)}',
      isPositive: false,
      subtitle: transaction.description,
    );
  }
  if (type == 'reversal') {
    return LoyaltyTransactionPresentation(
      title: 'Отмена начисления',
      amountLabel: '-${_formatBonus(transaction.amount)}',
      isPositive: false,
      subtitle: transaction.description,
    );
  }
  final delta = transaction.balanceDelta;
  final sign = delta > 0
      ? '+'
      : delta < 0
          ? '-'
          : '';
  return LoyaltyTransactionPresentation(
    title: transaction.description?.trim().isNotEmpty == true
        ? transaction.description!
        : 'Операция с бонусами',
    amountLabel: delta == 0
        ? _formatBonus(transaction.amount)
        : '$sign${_formatBonus(delta.abs())}',
    isPositive: delta > 0,
    subtitle: transaction.status,
  );
}

String _formatBonus(int value) {
  final raw = value.toString();
  final buffer = StringBuffer();
  for (var index = 0; index < raw.length; index++) {
    if (index > 0 && (raw.length - index) % 3 == 0) buffer.write(' ');
    buffer.write(raw[index]);
  }
  return buffer.toString();
}
