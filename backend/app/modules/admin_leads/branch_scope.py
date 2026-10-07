from __future__ import annotations

from dataclasses import dataclass

from fastapi import Depends
from sqlalchemy.orm import Session

from ...core.database.session import get_db_session
from ...core.exceptions.http import DomainHTTPException
from ...db.repositories.branch_repository import BranchRepository
from ..admin_auth.dependencies import get_current_admin_user
from ..admin_auth.schemas import AdminCurrentUserResponse
from ..admin_auth.service import AdminAuthService


LEAD_INBOX_ALLOWED_ROLES = (
    'super_admin',
    'operator',
    'sales_manager',
)


@dataclass(frozen=True)
class AdminLeadAccess:
    """Authoritative lead-inbox scope derived from the admin session."""

    admin_user: AdminCurrentUserResponse
    branch_id: str | None

    @property
    def is_global(self) -> bool:
        return self.branch_id is None

    def resolve_requested_branch(self, requested_branch_id: str | None) -> str | None:
        if self.is_global:
            return requested_branch_id
        if requested_branch_id is not None and requested_branch_id != self.branch_id:
            raise DomainHTTPException(
                code='branch_access_denied',
                message='This operator is not assigned to the requested branch.',
                status_code=403,
            )
        return self.branch_id


def get_admin_lead_access(
    current_admin: AdminCurrentUserResponse = Depends(get_current_admin_user),
    session: Session = Depends(get_db_session),
) -> AdminLeadAccess:
    if current_admin.role not in LEAD_INBOX_ALLOWED_ROLES:
        raise AdminAuthService.authorization_required_exception()

    if current_admin.role != 'operator':
        return AdminLeadAccess(admin_user=current_admin, branch_id=None)

    assigned_branch_id = current_admin.branch_id
    if not assigned_branch_id:
        raise DomainHTTPException(
            code='branch_not_assigned',
            message='An operating branch is not assigned to this operator.',
            status_code=403,
        )

    branch = BranchRepository(session).get_by_id(assigned_branch_id)
    if branch is None or not branch.is_active:
        raise DomainHTTPException(
            code='branch_inactive',
            message='The assigned branch is inactive.',
            status_code=403,
        )

    return AdminLeadAccess(admin_user=current_admin, branch_id=branch.id)
