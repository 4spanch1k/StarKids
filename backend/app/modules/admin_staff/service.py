from sqlalchemy import select
from sqlalchemy.orm import Session

from ...core.exceptions.http import DomainHTTPException, NotFoundException
from ...db.models.admin_user import AdminUser
from ...db.models.branch import Branch
from .schemas import AdminStaffBranchUpdateRequest, AdminStaffListResponse, AdminStaffResponse


class AdminStaffService:
    def __init__(self, session: Session) -> None:
        self.session = session

    def list_staff(self) -> AdminStaffListResponse:
        rows = self.session.execute(
            select(AdminUser, Branch)
            .outerjoin(Branch, Branch.id == AdminUser.branch_id)
            .order_by(AdminUser.full_name.asc(), AdminUser.email.asc(), AdminUser.id.asc())
        ).all()
        return AdminStaffListResponse(
            items=[self._serialize(user, branch) for user, branch in rows]
        )

    def update_branch(
        self,
        admin_user_id: str,
        payload: AdminStaffBranchUpdateRequest,
    ) -> AdminStaffResponse:
        user = self.session.scalar(
            select(AdminUser).where(AdminUser.id == admin_user_id)
        )
        if user is None:
            raise NotFoundException(
                code='admin_user_not_found',
                message='Admin user was not found.',
            )

        branch = None
        if user.role == 'operator':
            if not payload.branch_id:
                raise DomainHTTPException(
                    code='operator_branch_required',
                    message='An operator must have an assigned branch.',
                    status_code=400,
                )
            branch = self.session.scalar(
                select(Branch).where(Branch.id == payload.branch_id)
            )
            if branch is None:
                raise NotFoundException(
                    code='branch_not_found',
                    message='Branch was not found.',
                )
            if not branch.is_active:
                raise DomainHTTPException(
                    code='branch_inactive',
                    message='An operator can only be assigned to an active branch.',
                    status_code=400,
                )
            user.branch_id = branch.id
        else:
            if payload.branch_id is not None:
                raise DomainHTTPException(
                    code='branch_scope_not_supported',
                    message='Only operators can have a branch assignment.',
                    status_code=400,
                )
            user.branch_id = None

        self.session.add(user)
        self.session.commit()
        self.session.refresh(user)
        if branch is None and user.branch_id is not None:
            branch = self.session.scalar(select(Branch).where(Branch.id == user.branch_id))
        return self._serialize(user, branch)

    @staticmethod
    def _serialize(user: AdminUser, branch: Branch | None) -> AdminStaffResponse:
        return AdminStaffResponse(
            id=user.id,
            email=user.email,
            full_name=user.full_name,
            role=user.role,
            is_active=user.is_active,
            branch_id=user.branch_id,
            branch_name=branch.name if branch is not None else None,
        )
