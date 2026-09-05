from __future__ import annotations

from datetime import UTC, datetime
from decimal import Decimal, ROUND_DOWN
import logging
from uuid import uuid4

from sqlalchemy.exc import IntegrityError

from ...core.exceptions.http import DomainHTTPException, NotFoundException
from ...db.models.loyalty_account import LoyaltyAccount
from ...db.models.loyalty_rule import LoyaltyRule
from ...db.models.loyalty_transaction import LoyaltyTransaction
from ...db.models.loyalty_settings import LoyaltySettings
from ...db.repositories.loyalty_repository import LoyaltyRepository
from .constants import LOYALTY_EVENTS, LOYALTY_REWARD_TYPES

logger = logging.getLogger(__name__)


class LoyaltyService:
    """Single write boundary for loyalty balances and ledger entries."""

    def __init__(self, repository: LoyaltyRepository) -> None:
        self.repository = repository

    def get_or_create_account(self, user_id: str) -> LoyaltyAccount:
        account = self.repository.get_account(user_id)
        if account is not None:
            return account
        account = LoyaltyAccount(mobile_user_id=user_id)
        try:
            with self.repository.db.begin_nested():
                self.repository.db.add(account)
                self.repository.db.flush()
        except IntegrityError:
            pass
        account = self.repository.get_account(user_id)
        if account is None:
            raise RuntimeError('Could not create loyalty account.')
        return account

    def account_response(self, user_id: str) -> dict[str, int]:
        account = self.get_or_create_account(user_id)
        self.repository.db.flush()
        return {
            'balance': account.balance,
            'reservedBalance': account.reserved_balance,
            'availableBalance': account.balance - account.reserved_balance,
            'lifetimeEarned': account.lifetime_earned,
            'lifetimeSpent': account.lifetime_spent,
        }

    def get_settings(self) -> LoyaltySettings:
        settings = self.repository.get_settings()
        if settings is None:
            settings = LoyaltySettings(id=1)
            self.repository.db.add(settings)
            self.repository.db.flush()
        self._assert_fixed_bonus_value(settings)
        return settings

    def update_settings(self, *, max_redemption_percent: Decimal) -> LoyaltySettings:
        settings = self.repository.get_settings(for_update=True)
        if settings is None:
            settings = LoyaltySettings(id=1)
            self.repository.db.add(settings)
            self.repository.db.flush()
        self._assert_fixed_bonus_value(settings)
        settings.max_redemption_percent = max_redemption_percent
        self.repository.db.add(settings)
        self.repository.db.flush()
        return settings

    def max_redeemable_amount(self, order_amount_kzt: int) -> int:
        if order_amount_kzt < 0:
            raise DomainHTTPException(code='loyalty_invalid_order_amount', message='Сумма заказа не может быть отрицательной.', status_code=422)
        settings = self.get_settings()
        return int((Decimal(order_amount_kzt) * settings.max_redemption_percent / Decimal('100')).to_integral_value(rounding=ROUND_DOWN))

    def apply_event(
        self,
        *,
        user_id: str,
        event_type: str,
        source_type: str,
        source_id: str,
        cash_amount_kzt: int | None,
        idempotency_key: str,
        metadata: dict[str, object] | None = None,
    ) -> LoyaltyTransaction | None:
        existing = self.repository.get_transaction_by_idempotency(idempotency_key)
        if existing is not None:
            return existing
        active_rules = self.repository.active_rules(event_type)
        if len(active_rules) > 1:
            logger.critical('Ambiguous active loyalty rules event_type=%s rule_ids=%s', event_type, [item.id for item in active_rules])
            raise DomainHTTPException(code='loyalty_ambiguous_rule', message='Для этого события найдено несколько активных правил лояльности.', status_code=409)
        rule = active_rules[0] if active_rules else None
        if rule is None or rule.value <= 0:
            return None
        reward = self._calculate_reward(rule, cash_amount_kzt)
        if reward <= 0:
            return None
        account = self._locked_account(user_id)
        source_existing = self.repository.get_by_event_source('earn', source_type, source_id)
        if source_existing is not None:
            return source_existing
        return self._create_transaction(
            account=account,
            user_id=user_id,
            type='earn',
            amount=reward,
            balance_delta=reward,
            reserved_delta=0,
            source_type=source_type,
            source_id=source_id,
            idempotency_key=idempotency_key,
            status='posted',
            description=f'Начисление: {event_type}',
            metadata=metadata or {},
        )

    def earn(self, **kwargs) -> LoyaltyTransaction | None:
        return self.apply_event(**kwargs)

    def spend(self, *, user_id: str, amount: int, source_type: str, source_id: str, idempotency_key: str, description: str = 'Списание бонусов') -> LoyaltyTransaction:
        self._validate_amount(amount)
        existing = self.repository.get_transaction_by_idempotency(idempotency_key)
        if existing is not None:
            return existing
        account = self._locked_account(user_id)
        source_existing = self.repository.get_by_event_source('spend', source_type, source_id)
        if source_existing is not None:
            return source_existing
        available = account.balance - account.reserved_balance
        if available < amount:
            raise DomainHTTPException(code='loyalty_insufficient_balance', message='Недостаточно бонусов для списания.', status_code=409)
        return self._create_transaction(account=account, user_id=user_id, type='spend', amount=amount, balance_delta=-amount, reserved_delta=0, source_type=source_type, source_id=source_id, idempotency_key=idempotency_key, status='posted', description=description, metadata={})

    def reserve(self, *, user_id: str, amount: int, source_type: str, source_id: str, idempotency_key: str, order_amount_kzt: int | None = None, description: str = 'Резерв бонусов') -> LoyaltyTransaction:
        self._validate_amount(amount)
        existing = self.repository.get_transaction_by_idempotency(idempotency_key)
        if existing is not None:
            return existing
        if order_amount_kzt is not None and amount > self.max_redeemable_amount(order_amount_kzt):
            raise DomainHTTPException(code='loyalty_redemption_limit_exceeded', message='Сумма бонусов превышает допустимый лимит для заказа.', status_code=422)
        account = self._locked_account(user_id)
        source_existing = self.repository.get_by_event_source('reserve', source_type, source_id)
        if source_existing is not None:
            return source_existing
        if account.balance - account.reserved_balance < amount:
            raise DomainHTTPException(code='loyalty_insufficient_balance', message='Недостаточно доступных бонусов.', status_code=409)
        return self._create_transaction(account=account, user_id=user_id, type='reserve', amount=amount, balance_delta=0, reserved_delta=amount, source_type=source_type, source_id=source_id, idempotency_key=idempotency_key, status='reserved', description=description, metadata={})

    def capture(self, *, user_id: str, reservation_id: str, idempotency_key: str) -> LoyaltyTransaction:
        return self._settle_reservation(user_id=user_id, reservation_id=reservation_id, idempotency_key=idempotency_key, target='captured')

    def release(self, *, user_id: str, reservation_id: str, idempotency_key: str) -> LoyaltyTransaction:
        return self._settle_reservation(user_id=user_id, reservation_id=reservation_id, idempotency_key=idempotency_key, target='released')

    def reverse(self, *, user_id: str, original_transaction_id: str, idempotency_key: str) -> LoyaltyTransaction:
        existing = self.repository.get_transaction_by_idempotency(idempotency_key)
        if existing is not None:
            return existing
        original = self.repository.get_transaction(original_transaction_id)
        if original is None or original.mobile_user_id != user_id:
            raise NotFoundException(code='loyalty_transaction_not_found', message='Loyalty transaction was not found.')
        if original.type not in {'earn', 'capture'} or original.status != 'posted' and original.status != 'captured':
            raise DomainHTTPException(code='loyalty_invalid_reversal', message='Эту транзакцию нельзя отменить.', status_code=409)
        account = self._locked_account(user_id)
        source_existing = self.repository.get_by_event_source('reversal', 'loyalty_transaction', original.id)
        if source_existing is not None:
            return source_existing
        if account.balance - account.reserved_balance < original.amount:
            raise DomainHTTPException(code='loyalty_reversal_insufficient_balance', message='Нельзя отменить начисление: бонусы уже использованы.', status_code=409)
        return self._create_transaction(account=account, user_id=user_id, type='reversal', amount=original.amount, balance_delta=-original.amount, reserved_delta=0, source_type='loyalty_transaction', source_id=original.id, idempotency_key=idempotency_key, status='posted', description='Отмена начисления бонусов', metadata={'originalTransactionId': original.id})

    def list_transactions(self, user_id: str, *, limit: int, offset: int) -> tuple[list[LoyaltyTransaction], int]:
        return self.repository.list_transactions(user_id, limit=limit, offset=offset), self.repository.count_transactions(user_id)

    def _settle_reservation(self, *, user_id: str, reservation_id: str, idempotency_key: str, target: str) -> LoyaltyTransaction:
        existing = self.repository.get_transaction_by_idempotency(idempotency_key)
        if existing is not None:
            return existing
        reservation = self.repository.get_transaction(reservation_id, for_update=True)
        if reservation is None or reservation.mobile_user_id != user_id or reservation.type != 'reserve':
            raise NotFoundException(code='loyalty_reservation_not_found', message='Резерв бонусов не найден.')
        existing = self.repository.get_transaction_by_idempotency(idempotency_key)
        if existing is not None:
            return existing
        if reservation.status != 'reserved':
            raise DomainHTTPException(code='loyalty_reservation_already_settled', message='Резерв бонусов уже обработан.', status_code=409)
        account = self._locked_account(user_id)
        transaction = self._create_transaction(account=account, user_id=user_id, type='capture' if target == 'captured' else 'release', amount=reservation.amount, balance_delta=-reservation.amount if target == 'captured' else 0, reserved_delta=-reservation.amount, source_type='loyalty_reservation', source_id=reservation.id, idempotency_key=idempotency_key, status='posted', description='Подтверждение бонусов' if target == 'captured' else 'Возврат резерва бонусов', metadata={'reservationId': reservation.id})
        reservation.status = target
        self.repository.db.add(reservation)
        return transaction

    def _locked_account(self, user_id: str) -> LoyaltyAccount:
        account = self.repository.get_account(user_id, for_update=True)
        if account is None:
            account = self.get_or_create_account(user_id)
            account = self.repository.get_account(user_id, for_update=True)
        if account is None:
            raise RuntimeError('Could not lock loyalty account.')
        return account

    @staticmethod
    def _assert_fixed_bonus_value(settings: LoyaltySettings) -> None:
        if settings.bonus_value_kzt != Decimal('1'):
            logger.critical('Invalid loyalty bonus value invariant: settings_id=%s value=%s', settings.id, settings.bonus_value_kzt)
            raise RuntimeError('Loyalty invariant violated: one bonus must equal one KZT.')

    def _create_transaction(self, *, account: LoyaltyAccount, user_id: str, type: str, amount: int, balance_delta: int, reserved_delta: int, source_type: str, source_id: str, idempotency_key: str, status: str, description: str, metadata: dict[str, object]) -> LoyaltyTransaction:
        next_balance = account.balance + balance_delta
        next_reserved = account.reserved_balance + reserved_delta
        if next_balance < 0 or next_reserved < 0 or next_reserved > next_balance:
            raise DomainHTTPException(code='loyalty_balance_invariant', message='Операция нарушает баланс бонусов.', status_code=409)
        account.balance = next_balance
        account.reserved_balance = next_reserved
        if balance_delta > 0:
            account.lifetime_earned += balance_delta
        if balance_delta < 0:
            account.lifetime_spent += -balance_delta
        self.repository.db.add(account)
        transaction = LoyaltyTransaction(mobile_user_id=user_id, account_id=account.id, type=type, amount=amount, balance_delta=balance_delta, reserved_delta=reserved_delta, source_type=source_type, source_id=source_id, idempotency_key=idempotency_key, status=status, description=description, metadata_json=metadata)
        self.repository.db.add(transaction)
        self.repository.db.flush()
        logger.info('loyalty transaction user_id=%s type=%s source_type=%s source_id=%s', user_id, type, source_type, source_id)
        return transaction

    @staticmethod
    def _calculate_reward(rule: LoyaltyRule, cash_amount_kzt: int | None) -> int:
        if rule.reward_type == 'fixed':
            return int(rule.value.to_integral_value(rounding=ROUND_DOWN))
        if rule.reward_type == 'percent' and cash_amount_kzt is not None:
            return int((Decimal(cash_amount_kzt) * rule.value / Decimal('100')).to_integral_value(rounding=ROUND_DOWN))
        return 0

    @staticmethod
    def _validate_amount(amount: int) -> None:
        if amount <= 0:
            raise DomainHTTPException(code='loyalty_invalid_amount', message='Количество бонусов должно быть больше нуля.', status_code=422)


def validate_rule(event_type: str, reward_type: str, value: Decimal, starts_at: datetime | None, ends_at: datetime | None) -> None:
    if event_type not in LOYALTY_EVENTS:
        raise DomainHTTPException(code='loyalty_invalid_event_type', message='Неизвестный тип события лояльности.', status_code=422)
    if reward_type not in LOYALTY_REWARD_TYPES:
        raise DomainHTTPException(code='loyalty_invalid_reward_type', message='Неизвестный тип начисления.', status_code=422)
    if reward_type == 'percent' and value > 100:
        raise DomainHTTPException(code='loyalty_invalid_percent', message='Процент не может быть больше 100.', status_code=422)
    if value < 0:
        raise DomainHTTPException(code='loyalty_invalid_value', message='Значение правила не может быть отрицательным.', status_code=422)
    if ends_at is not None and starts_at is not None and ends_at <= starts_at:
        raise DomainHTTPException(code='loyalty_invalid_period', message='Дата окончания должна быть позже даты начала.', status_code=422)


def ensure_rule_does_not_overlap(
    repository: LoyaltyRepository,
    *,
    event_type: str,
    starts_at: datetime | None,
    ends_at: datetime | None,
    exclude_id: str | None = None,
) -> None:
    repository.lock_rule_event(event_type)
    existing = repository.overlapping_active_rule(
        event_type=event_type,
        starts_at=starts_at,
        ends_at=ends_at,
        exclude_id=exclude_id,
    )
    if existing is not None:
        raise DomainHTTPException(
            code='loyalty_rule_overlap',
            message=f'Активное правило {event_type} пересекается с правилом {existing.id}.',
            status_code=409,
        )


def to_rule_response(rule: LoyaltyRule) -> dict[str, object]:
    return {'id': rule.id, 'eventType': rule.event_type, 'rewardType': rule.reward_type, 'value': rule.value, 'isActive': rule.is_active, 'startsAt': rule.starts_at, 'endsAt': rule.ends_at}


def to_transaction_response(transaction: LoyaltyTransaction) -> dict[str, object]:
    return {'id': transaction.id, 'type': transaction.type, 'amount': transaction.amount, 'balanceDelta': transaction.balance_delta, 'reservedDelta': transaction.reserved_delta, 'sourceType': transaction.source_type, 'sourceId': transaction.source_id, 'status': transaction.status, 'description': transaction.description, 'createdAt': transaction.created_at}


def to_settings_response(settings: LoyaltySettings) -> dict[str, Decimal]:
    return {'maxRedemptionPercent': settings.max_redemption_percent, 'bonusValueKzt': settings.bonus_value_kzt}
