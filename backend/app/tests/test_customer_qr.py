from __future__ import annotations

from datetime import datetime, timedelta, timezone
import time
import unittest

from app.db.models.mobile_user import MobileUser
from app.modules.admin_auth.schemas import AdminCurrentUserResponse
from app.modules.admin_tickets.customer_identification_service import (
    CustomerIdentificationService,
)
from app.modules.mobile_profile.customer_qr_service import CustomerQrService


class CustomerQrServiceTests(unittest.TestCase):
    def setUp(self) -> None:
        self.service = CustomerQrService('s' * 48)

    def test_valid_payload_round_trips_and_is_short_lived(self) -> None:
        payload, expires_at = self.service.build_payload('user-123')
        self.assertEqual(self.service.verify_payload(payload), 'user-123')
        self.assertGreater(expires_at, datetime.now(timezone.utc))
        self.assertLessEqual(expires_at, datetime.now(timezone.utc) + timedelta(minutes=10, seconds=1))

    def test_tampering_expiry_or_signature_is_rejected(self) -> None:
        payload, _ = self.service.build_payload('user-123')
        parts = payload.split(':')
        parts[2] = 'other-user'
        self.assertIsNone(self.service.verify_payload(':'.join(parts)))
        parts = payload.split(':')
        parts[3] = str(int(time.time()) + 3600)
        self.assertIsNone(self.service.verify_payload(':'.join(parts)))
        signature_tampered = payload[:-64] + ('0' if payload[-64] != '0' else '1') + payload[-63:]
        self.assertIsNone(self.service.verify_payload(signature_tampered))

    def test_expired_and_other_qr_domains_are_rejected(self) -> None:
        self.assertIsNone(self.service.verify_payload('bb_ticket:v1:ticket-1:abc'))
        self.assertIsNone(self.service.verify_payload('bb_pass:v1:pass-1:abc'))
        expired = 'bb_customer:v1:user-123:1:' + ('0' * 64)
        self.assertIsNone(self.service.verify_payload(expired))


class CustomerIdentificationServiceTests(unittest.TestCase):
    def setUp(self) -> None:
        self.qr = CustomerQrService('s' * 48)
        self.user = MobileUser(
            id='user-123',
            phone='+77071234567',
            first_name='Айжан',
            last_name='С.',
            is_active=True,
        )
        self.branch = type('Branch', (), {'id': 'branch-main', 'is_active': True})()
        self.users = {'user-123': self.user}
        self.accounts = {'user-123': type('Account', (), {'balance': 1250})()}

        class Users:
            def get_by_id(_, user_id):
                return self.users.get(user_id)

        class Loyalty:
            def get_account(_, user_id):
                return self.accounts.get(user_id)

        class Branches:
            def get_by_id(_, branch_id):
                return self.branch if branch_id == self.branch.id else None

        self.service = CustomerIdentificationService(
            user_repository=Users(),
            loyalty_repository=Loyalty(),
            branch_repository=Branches(),
            customer_qr_service=self.qr,
        )
        self.admin = AdminCurrentUserResponse(
            id='admin-1',
            email='operator@example.com',
            full_name='Operator',
            role='operator',
            branch_id='branch-main',
        )

    def test_identifies_customer_without_admission_side_effects(self) -> None:
        payload, _ = self.qr.build_payload(self.user.id)
        response = self.service.identify(
            qr_payload=payload,
            branch_id='branch-main',
            admin_user=self.admin,
        )
        self.assertEqual(response.outcome, 'identified')
        self.assertEqual(response.customerId, self.user.id)
        self.assertEqual(response.displayName, 'Айжан С.')
        self.assertEqual(response.phoneMasked, '+7 *** *** 45 67')
        self.assertEqual(response.bonusBalance, 1250)

    def test_invalid_customer_qr_is_fail_closed(self) -> None:
        with self.assertRaises(Exception) as raised:
            self.service.identify(
                qr_payload='bb_ticket:v1:ticket-1:signature',
                branch_id='branch-main',
                admin_user=self.admin,
            )
        self.assertEqual(getattr(raised.exception, 'code', None), 'invalid_qr')
