from ...db.repositories.content_block_repository import ContentBlockRepository
from ...db.repositories.faq_repository import FAQRepository
from .schemas import ContentBlockResponse, FAQResponse


class ContentService:
    def __init__(
        self,
        *,
        faq_repository: FAQRepository | None = None,
        content_block_repository: ContentBlockRepository | None = None,
    ) -> None:
        self.faq_repository = faq_repository or FAQRepository()
        self.content_block_repository = content_block_repository or ContentBlockRepository()

    def list_faqs(self) -> list[FAQResponse]:
        return [
            FAQResponse(
                id=faq.id,
                question=faq.question,
                answer=faq.answer,
            )
            for faq in self.faq_repository.list_mobile()
        ]

    def list_content_blocks(self, surface: str) -> list[ContentBlockResponse]:
        return [
            ContentBlockResponse(
                id=block.id,
                surface=block.surface,
                key=block.key,
                title=block.title,
                body=block.body,
                cta_label=block.cta_label,
            )
            for block in self.content_block_repository.list_mobile(surface=surface)
        ]
