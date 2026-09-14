from ...core.exceptions.http import DomainHTTPException, NotFoundException
from ...db.models.admin_user import AdminUser
from ...db.repositories.branch_repository import BranchRepository
from ..admin_auth.schemas import AdminCurrentUserResponse


def require_active_branch_access(
    *,
    admin_user: AdminCurrentUserResponse | AdminUser,
    requested_branch_id: str,
    branch_repository: BranchRepository,
):
    """Validate the operating branch before any ticket state mutation.

    Operators are intentionally fail-closed: a missing assignment, a stale
    assignment, an inactive branch, or a mismatch is never interpreted as
    global access. Super admins retain their existing global branch scope.
    """
    branch = branch_repository.get_by_id(requested_branch_id)
    if branch is None:
        raise NotFoundException(
            code='branch_not_found',
            message='Branch was not found.',
        )
    if not branch.is_active:
        raise DomainHTTPException(
            code='branch_inactive',
            message='This branch is inactive.',
            status_code=403,
        )

    if admin_user.role == 'super_admin':
        return branch

    if admin_user.role != 'operator':
        raise DomainHTTPException(
            code='insufficient_role',
            message='You do not have access to ticket admission.',
            status_code=403,
        )

    assigned_branch_id = getattr(admin_user, 'branch_id', None)
    if not assigned_branch_id:
        raise DomainHTTPException(
            code='branch_not_assigned',
            message='An operating branch is not assigned to this operator.',
            status_code=403,
        )
    assigned_branch = branch_repository.get_by_id(assigned_branch_id)
    if assigned_branch is None or not assigned_branch.is_active:
        raise DomainHTTPException(
            code='branch_inactive',
            message='The assigned branch is inactive.',
            status_code=403,
        )
    if assigned_branch.id != branch.id:
        raise DomainHTTPException(
            code='branch_access_denied',
            message='This operator is not assigned to the requested branch.',
            status_code=403,
        )
    return branch


def require_operator_branch_scope(
    *,
    admin_user: AdminCurrentUserResponse | AdminUser,
    branch_repository: BranchRepository,
) -> str | None:
    """Return the branch filter for lookup, or None for a super admin."""
    if admin_user.role == 'super_admin':
        return None
    if admin_user.role != 'operator':
        raise DomainHTTPException(
            code='insufficient_role',
            message='You do not have access to ticket admission.',
            status_code=403,
        )
    assigned_branch_id = getattr(admin_user, 'branch_id', None)
    if not assigned_branch_id:
        raise DomainHTTPException(
            code='branch_not_assigned',
            message='An operating branch is not assigned to this operator.',
            status_code=403,
        )
    assigned_branch = branch_repository.get_by_id(assigned_branch_id)
    if assigned_branch is None or not assigned_branch.is_active:
        raise DomainHTTPException(
            code='branch_inactive',
            message='The assigned branch is inactive.',
            status_code=403,
        )
    return assigned_branch.id
