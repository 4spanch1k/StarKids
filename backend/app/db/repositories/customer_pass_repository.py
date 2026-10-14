from sqlalchemy import select

from ..models.branch import Branch
from ..models.customer_pass import CustomerPass
from ..models.mobile_child import MobileChild
from .base import Repository


class CustomerPassRepository(Repository):
    def get_by_payment_for_update(self, payment_id: str) -> CustomerPass | None:
        return self.db.scalar(
            select(CustomerPass).where(CustomerPass.mobile_payment_id == payment_id).with_for_update()
        )

    def get_for_user(self, pass_id: str, user_id: str, *, for_update: bool = False) -> CustomerPass | None:
        statement = select(CustomerPass).where(CustomerPass.id == pass_id, CustomerPass.mobile_user_id == user_id)
        if for_update:
            statement = statement.with_for_update()
        return self.db.scalar(statement)

    def list_for_user(self, user_id: str) -> list[tuple[CustomerPass, MobileChild, Branch | None]]:
        statement = (
            select(CustomerPass, MobileChild, Branch)
            .join(MobileChild, MobileChild.id == CustomerPass.child_id)
            .outerjoin(Branch, Branch.id == CustomerPass.branch_id_snapshot)
            .where(CustomerPass.mobile_user_id == user_id)
            .order_by(CustomerPass.created_at.desc())
        )
        return list(self.db.execute(statement).all())

    def list_all(self) -> list[tuple[CustomerPass, MobileChild, Branch | None]]:
        statement = (
            select(CustomerPass, MobileChild, Branch)
            .join(MobileChild, MobileChild.id == CustomerPass.child_id)
            .outerjoin(Branch, Branch.id == CustomerPass.branch_id_snapshot)
            .order_by(CustomerPass.created_at.desc())
        )
        return list(self.db.execute(statement).all())

    def exists_for_child(self, child_id: str) -> bool:
        return self.db.scalar(
            select(CustomerPass.id).where(CustomerPass.child_id == child_id).limit(1)
        ) is not None

    def add(self, customer_pass: CustomerPass) -> CustomerPass:
        self.db.add(customer_pass)
        return customer_pass
