from collections.abc import Sequence

from sqlalchemy import delete, select

from ..models.branch_ticket_item import BranchTicketItem
from ..models.branch_ticket_note import BranchTicketNote
from .base import Repository


class BranchTicketRepository(Repository):
    def has_ticket_config(self, branch_id: str) -> bool:
        item_statement = select(BranchTicketItem.id).where(BranchTicketItem.branch_id == branch_id)
        if self.db.scalar(item_statement) is not None:
            return True

        note_statement = select(BranchTicketNote.id).where(BranchTicketNote.branch_id == branch_id)
        return self.db.scalar(note_statement) is not None

    def list_items(
        self,
        branch_id: str,
        *,
        active_only: bool,
    ) -> list[BranchTicketItem]:
        statement = select(BranchTicketItem).where(BranchTicketItem.branch_id == branch_id)
        if active_only:
            statement = statement.where(BranchTicketItem.is_active.is_(True))
        statement = statement.order_by(
            BranchTicketItem.display_order.asc(),
            BranchTicketItem.title.asc(),
        )
        return list(self.db.scalars(statement).all())

    def get_active_item(self, ticket_item_id: str) -> BranchTicketItem | None:
        statement = select(BranchTicketItem).where(
            BranchTicketItem.id == ticket_item_id,
            BranchTicketItem.is_active.is_(True),
        )
        return self.db.scalar(statement)

    def list_notes(
        self,
        branch_id: str,
        *,
        active_only: bool,
    ) -> list[BranchTicketNote]:
        statement = select(BranchTicketNote).where(BranchTicketNote.branch_id == branch_id)
        if active_only:
            statement = statement.where(BranchTicketNote.is_active.is_(True))
        statement = statement.order_by(
            BranchTicketNote.display_order.asc(),
            BranchTicketNote.text.asc(),
        )
        return list(self.db.scalars(statement).all())

    def replace_branch_ticket_config(
        self,
        *,
        branch_id: str,
        item_payloads: Sequence[dict[str, object]],
        note_payloads: Sequence[dict[str, object]],
    ) -> None:
        self.db.execute(delete(BranchTicketItem).where(BranchTicketItem.branch_id == branch_id))
        self.db.execute(delete(BranchTicketNote).where(BranchTicketNote.branch_id == branch_id))

        for payload in item_payloads:
            self.db.add(BranchTicketItem(branch_id=branch_id, **payload))

        for payload in note_payloads:
            self.db.add(BranchTicketNote(branch_id=branch_id, **payload))

        self.db.commit()
