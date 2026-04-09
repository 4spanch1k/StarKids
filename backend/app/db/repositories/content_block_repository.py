from sqlalchemy import select

from ..models.content_block import ContentBlock
from .base import Repository


class ContentBlockRepository(Repository):
    def list_admin(
        self,
        *,
        surface: str | None = None,
        is_active: bool | None = None,
        is_published: bool | None = None,
    ) -> list[ContentBlock]:
        statement = select(ContentBlock)
        if surface:
            statement = statement.where(ContentBlock.surface == surface)
        if is_active is not None:
            statement = statement.where(ContentBlock.is_active.is_(is_active))
        if is_published is not None:
            statement = statement.where(ContentBlock.is_published.is_(is_published))
        statement = statement.order_by(
            ContentBlock.surface.asc(),
            ContentBlock.display_order.asc(),
            ContentBlock.key.asc(),
        )
        return list(self.db.scalars(statement).all())

    def list_mobile(self, *, surface: str) -> list[ContentBlock]:
        return self.list_admin(surface=surface, is_active=True, is_published=True)

    def get_by_id(self, block_id: str) -> ContentBlock | None:
        statement = select(ContentBlock).where(ContentBlock.id == block_id)
        return self.db.scalar(statement)

    def surface_key_exists(
        self,
        *,
        surface: str,
        key: str,
        exclude_id: str | None = None,
    ) -> bool:
        statement = select(ContentBlock.id).where(
            ContentBlock.surface == surface,
            ContentBlock.key == key,
        )
        if exclude_id:
            statement = statement.where(ContentBlock.id != exclude_id)
        return self.db.scalar(statement) is not None

    def create(self, payload: dict[str, object]) -> ContentBlock:
        block = ContentBlock(**payload)
        self.db.add(block)
        self.db.commit()
        self.db.refresh(block)
        return block

    def save(self, block: ContentBlock) -> ContentBlock:
        self.db.add(block)
        self.db.commit()
        self.db.refresh(block)
        return block
