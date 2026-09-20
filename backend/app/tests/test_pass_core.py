from datetime import UTC, datetime, timedelta
import unittest

from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from app.core.time.business_time import business_today
from app.core.config.settings import Settings
from app.db.models import Base
from app.db.models.admin_user import AdminUser
from app.db.models.branch import Branch
from app.db.models.mobile_child import MobileChild
from app.db.models.mobile_payment import MobilePayment
from app.db.models.mobile_user import MobileUser
from app.db.models.pass_plan import PassPlan
from app.db.models.customer_pass import CustomerPass
from app.db.models.customer_pass import CustomerPass
from app.db.models.pass_redemption import PassRedemption
from app.db.models.visit import Visit
from app.db.repositories.branch_repository import BranchRepository
from app.db.repositories.customer_pass_repository import CustomerPassRepository
from app.db.repositories.mobile_child_repository import MobileChildRepository
from app.db.repositories.pass_plan_repository import PassPlanRepository
from app.db.repositories.pass_redemption_repository import PassRedemptionRepository
from app.db.repositories.visit_repository import VisitRepository
from app.db.repositories.branch_ticket_repository import BranchTicketRepository
from app.db.repositories.issued_ticket_repository import IssuedTicketRepository
from app.db.repositories.mobile_payment_repository import MobilePaymentRepository
from app.db.repositories.loyalty_repository import LoyaltyRepository
from app.modules.loyalty.service import LoyaltyService
from app.modules.mobile_payments.freedompay_client import FreedomPayInitResult
from app.modules.mobile_payments.issued_ticket_service import IssuedTicketService
from app.modules.mobile_payments.service import MobilePaymentService
from app.modules.mobile_payments.ticket_qr_service import TicketQrService
from app.modules.passes.qr_service import PassQrService
from app.modules.passes.schemas import PassPlanCreateRequest
from app.modules.passes.service import PassService


class PassCoreTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.engine = create_engine('sqlite://', connect_args={'check_same_thread': False}, poolclass=StaticPool)
        cls.SessionLocal = sessionmaker(bind=cls.engine, class_=Session, expire_on_commit=False)
        Base.metadata.create_all(cls.engine)

    @classmethod
    def tearDownClass(cls) -> None:
        Base.metadata.drop_all(cls.engine)

    def setUp(self) -> None:
        self.session = self.SessionLocal()
        for model in (PassRedemption, Visit, CustomerPass, PassPlan, MobilePayment, MobileChild, MobileUser, Branch, AdminUser):
            self.session.query(model).delete()
        self.session.add(Branch(
            id='branch-pass', slug='pass', name='Pass Branch', city='Almaty', address='Test',
            short_label='Pass', working_hours='00:00 - 23:59', description='Test',
            phone='+77000000000', whatsapp_phone='+77000000000', gallery_image_urls=[], facilities=[], is_active=True,
        ))
        self.session.add(MobileUser(id='pass-user', email='pass@example.com', phone='+77000000000', is_active=True))
        self.session.add(MobileChild(id='pass-child', user_id='pass-user', name='Child', birth_date=business_today(), gender='unspecified'))
        self.session.add(AdminUser(id='pass-admin', email='admin-pass@example.com', full_name='Pass', password_hash='x', role='super_admin', is_active=True))
        self.session.commit()
        self.service = PassService(
            plan_repository=PassPlanRepository(self.session),
            customer_pass_repository=CustomerPassRepository(self.session),
            redemption_repository=PassRedemptionRepository(self.session),
            child_repository=MobileChildRepository(self.session),
            branch_repository=BranchRepository(self.session),
            visit_repository=VisitRepository(self.session),
            qr_service=PassQrService('p' * 48),
            now_provider=lambda: datetime.now(UTC),
        )

    def tearDown(self) -> None:
        self.session.close()

    def _plan(self, **kwargs) -> PassPlan:
        values = dict(id='plan-pass', name='BOOM 4', price_tenge=10000, visit_limit=4, validity_days=30, daily_limit=1, branch_id=None, is_active=True)
        values.update(kwargs)
        plan = PassPlan(**values)
        self.session.add(plan)
        self.session.commit()
        return plan

    def _payment(self, plan: PassPlan) -> MobilePayment:
        payment = MobilePayment(
            id='payment-pass', mobile_user_id='pass-user', branch_id='branch-pass',
            payable_entity_type='pass_purchase', payable_entity_id=plan.id,
            local_order_id='order-pass', idempotency_key='pass-idempotency', amount_tenge=plan.price_tenge,
            gross_amount_tenge=plan.price_tenge, cash_amount_tenge=plan.price_tenge,
            currency='KZT', quantity=1, visit_date=None, ticket_items=[], status='paid',
            init_payload={'passSnapshot': {'childId': 'pass-child', 'passPlanId': plan.id, 'planName': plan.name, 'priceTenge': plan.price_tenge, 'visitLimit': plan.visit_limit, 'validityDays': plan.validity_days, 'dailyLimit': plan.daily_limit, 'branchId': plan.branch_id}},
            callback_payload={}, paid_at=datetime.now(UTC), pass_issuance_required=True,
        )
        self.session.add(payment)
        self.session.commit()
        return payment

    def _payment_service(self) -> MobilePaymentService:
        settings = Settings(app_env='test', ticket_qr_secret='t' * 48)
        class FakeClient:
            def init_payment(self, params: dict[str, object]) -> FreedomPayInitResult:
                return FreedomPayInitResult(external_payment_id='fp-pass', payment_url='https://pay.test/pass', raw_payload={})
        return MobilePaymentService(
            settings=settings, payment_repository=MobilePaymentRepository(self.session),
            branch_repository=BranchRepository(self.session), ticket_repository=BranchTicketRepository(self.session),
            freedompay_client=FakeClient(), issued_ticket_service=IssuedTicketService(IssuedTicketRepository(self.session)),
            ticket_qr_service=TicketQrService('t' * 48), visit_repository=VisitRepository(self.session),
            loyalty_service=LoyaltyService(LoyaltyRepository(self.session)), pass_service=self.service,
        )

    def test_plan_validation_and_snapshot(self) -> None:
        plan = self._plan()
        payment = self._payment(plan)
        customer_pass = self.service.issue_for_paid_payment(payment)
        self.assertEqual(customer_pass.remaining_visits, 4)
        plan.name = 'Changed later'
        plan.price_tenge = 1
        self.session.commit()
        self.session.refresh(customer_pass)
        self.assertEqual(customer_pass.name_snapshot, 'BOOM 4')
        self.assertEqual(customer_pass.price_tenge_snapshot, 10000)

    def test_qr_redemption_replay_and_exhaustion(self) -> None:
        plan = self._plan(visit_limit=1)
        payment = self._payment(plan)
        customer_pass = self.service.issue_for_paid_payment(payment)
        qr = self.service.qr.build_payload(customer_pass.id)
        first = self.service.redeem(qr_payload=qr, branch_id='branch-pass', admin_user=self.session.get(AdminUser, 'pass-admin'))
        self.assertEqual(first.outcome, 'redeemed')
        self.assertEqual(first.remainingVisits, 0)
        replay = self.service.redeem(qr_payload=qr, branch_id='branch-pass', admin_user=self.session.get(AdminUser, 'pass-admin'))
        self.assertEqual(replay.outcome, 'already_used_today')

    def test_qr_rejects_tampering(self) -> None:
        self.assertIsNone(self.service.qr.verify_payload('bb_pass:v1:pass:x' * 1))

    def test_purchase_ownership_and_branch_scope(self) -> None:
        plan = self._plan(branch_id='branch-pass')
        child, resolved, branch = self.service.validate_purchase(
            user_id='pass-user', child_id='pass-child', plan_id=plan.id, branch_id='branch-pass'
        )
        self.assertEqual((child.id, resolved.id, branch.id), ('pass-child', plan.id, 'branch-pass'))
        with self.assertRaises(Exception):
            self.service.validate_purchase(
                user_id='other-user', child_id='pass-child', plan_id=plan.id, branch_id='branch-pass'
            )

    def test_global_plan_can_be_purchased_at_active_branch(self) -> None:
        plan = self._plan(branch_id=None)
        _, _, branch = self.service.validate_purchase(
            user_id='pass-user', child_id='pass-child', plan_id=plan.id, branch_id='branch-pass'
        )
        self.assertEqual(branch.id, 'branch-pass')

    def test_paid_callback_dispatches_only_to_customer_pass(self) -> None:
        plan = self._plan()
        payment = self._payment(plan)
        service = self._payment_service()
        service._process_successful_callback_atomically(
            payment=payment, payload={'pg_result': '1'}, external_payment_id='fp-pass', paid_at=datetime.now(UTC)
        )
        service._process_successful_callback_atomically(
            payment=payment, payload={'pg_result': '1'}, external_payment_id='fp-pass', paid_at=datetime.now(UTC)
        )
        self.session.expire_all()
        stored = self.session.get(MobilePayment, payment.id)
        self.assertEqual(stored.status, 'paid')
        self.assertFalse(stored.pass_issuance_required)
        self.assertEqual(self.session.query(CustomerPass).count(), 1)


if __name__ == '__main__':
    unittest.main()
