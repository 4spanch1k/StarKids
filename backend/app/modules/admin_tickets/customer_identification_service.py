from __future__ import annotations

from ...core.exceptions.http import DomainHTTPException, NotFoundException
from ...db.models.mobile_user import MobileUser
from ...db.repositories.branch_repository import BranchRepository
from ...db.repositories.loyalty_repository import LoyaltyRepository
from ...db.repositories.mobile_user_repository import MobileUserRepository
from ..admin_auth.schemas import AdminCurrentUserResponse
from ..mobile_profile.customer_qr_service import CustomerQrService
from .branch_scope import require_active_branch_access
from .schemas import AdminCustomerIdentificationResponse


class CustomerIdentificationService:
    """Identify a customer from a signed Customer QR without admission side effects."""

    def __init__(
        self,
        *,
        user_repository: MobileUserRepository,
        loyalty_repository: LoyaltyRepository,
        branch_repository: BranchRepository,
        customer_qr_service: CustomerQrService,
    ) -> None:
        self._user_repository = user_repository
        self._loyalty_repository = loyalty_repository
        self._branch_repository = branch_repository
        self._customer_qr_service = customer_qr_service

    def identify(
        self,
        *,
        qr_payload: str,
        branch_id: str,
        admin_user: AdminCurrentUserResponse,
    ) -> AdminCustomerIdentificationResponse:
        branch = require_active_branch_access(
            admin_user=admin_user,
            requested_branch_id=branch_id,
            branch_repository=self._branch_repository,
        )
        user_id = self._customer_qr_service.verify_payload(qr_payload)
        if user_id is None:
            raise DomainHTTPException(
                code='invalid_qr',
                message='QR payload is invalid.',
            )
        user = self._user_repository.get_by_id(user_id)
        if user is None:
            raise NotFoundException(
                code='customer_not_found',
                message='Customer was not found.',
            )
        if not user.is_active:
            raise DomainHTTPException(
                code='customer_inactive',
                message='Customer is inactive.',
                status_code=403,
            )
        account = self._loyalty_repository.get_account(user.id)
        return AdminCustomerIdentificationResponse(
            customerId=user.id,
            displayName=self._display_name(user),
            phoneMasked=self._mask_phone(user.phone),
            bonusBalance=account.balance if account is not None else 0,
            branchId=branch.id,
        )

    @staticmethod
    def _display_name(user: MobileUser) -> str:
        full_name = ' '.join(
            part.strip()
            for part in (user.first_name, user.last_name)
            if part and part.strip()
        )
        return full_name or 'Клиент Boom Bala'

    @staticmethod
    def _mask_phone(phone: str | None) -> str | None:
        if not phone:
            return None
        digits = ''.join(character for character in phone if character.isdigit())
        if len(digits) < 4:
            return '***'
        suffix = digits[-4:]
        if digits.startswith('7'):
            return f'+7 *** *** {suffix[:2]} {suffix[2:]}'
        return f'*** *** {suffix[:2]} {suffix[2:]}'
