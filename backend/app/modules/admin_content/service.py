from ...core.exceptions.http import DomainHTTPException, NotFoundException
from ...db.models.content_block import ContentBlock
from ...db.models.faq_entry import FAQEntry
from ...db.repositories.content_block_repository import ContentBlockRepository
from ...db.repositories.faq_repository import FAQRepository
from .schemas import (
    AdminContentBlockCreateRequest,
    AdminContentBlockListQuery,
    AdminContentBlockResponse,
    AdminContentBlockUpdateRequest,
    AdminFAQCreateRequest,
    AdminFAQListQuery,
    AdminFAQResponse,
    AdminFAQUpdateRequest,
)

CONTENT_ADMIN_ALLOWED_ROLES = ('super_admin', 'content_manager')


class AdminContentService:
    def __init__(
        self,
        *,
        faq_repository: FAQRepository | None = None,
        content_block_repository: ContentBlockRepository | None = None,
    ) -> None:
        self.faq_repository = faq_repository or FAQRepository()
        self.content_block_repository = content_block_repository or ContentBlockRepository()

    def list_faqs(self, query: AdminFAQListQuery) -> list[AdminFAQResponse]:
        return [
            AdminFAQResponse(
                id=faq.id,
                question=faq.question,
                answer=faq.answer,
                display_order=faq.display_order,
                is_active=faq.is_active,
                is_published=faq.is_published,
            )
            for faq in self.faq_repository.list_admin(
                is_active=query.is_active,
                is_published=query.is_published,
            )
        ]

    def get_faq(self, faq_id: str) -> AdminFAQResponse:
        faq = self._get_faq_or_404(faq_id)
        return AdminFAQResponse(
            id=faq.id,
            question=faq.question,
            answer=faq.answer,
            display_order=faq.display_order,
            is_active=faq.is_active,
            is_published=faq.is_published,
        )

    def create_faq(self, payload: AdminFAQCreateRequest) -> AdminFAQResponse:
        faq = self.faq_repository.create(payload.model_dump())
        return self.get_faq(faq.id)

    def update_faq(self, faq_id: str, payload: AdminFAQUpdateRequest) -> AdminFAQResponse:
        faq = self._get_faq_or_404(faq_id)
        changes = payload.model_dump(exclude_unset=True)
        if not changes:
            return self.get_faq(faq_id)
        for key, value in changes.items():
            setattr(faq, key, value)
        saved = self.faq_repository.save(faq)
        return self.get_faq(saved.id)

    def list_content_blocks(
        self,
        query: AdminContentBlockListQuery,
    ) -> list[AdminContentBlockResponse]:
        return [
            self._serialize_content_block(block)
            for block in self.content_block_repository.list_admin(
                surface=query.surface,
                is_active=query.is_active,
                is_published=query.is_published,
            )
        ]

    def get_content_block(self, block_id: str) -> AdminContentBlockResponse:
        block = self._get_content_block_or_404(block_id)
        return self._serialize_content_block(block)

    def create_content_block(
        self,
        payload: AdminContentBlockCreateRequest,
    ) -> AdminContentBlockResponse:
        self._ensure_surface_key_available(payload.surface, payload.key)
        block = self.content_block_repository.create(payload.model_dump())
        return self.get_content_block(block.id)

    def update_content_block(
        self,
        block_id: str,
        payload: AdminContentBlockUpdateRequest,
    ) -> AdminContentBlockResponse:
        block = self._get_content_block_or_404(block_id)
        changes = payload.model_dump(exclude_unset=True)
        if not changes:
            return self.get_content_block(block_id)

        next_surface = changes.get('surface', block.surface)
        next_key = changes.get('key', block.key)
        if next_surface != block.surface or next_key != block.key:
            self._ensure_surface_key_available(next_surface, next_key, exclude_id=block.id)

        for key, value in changes.items():
            setattr(block, key, value)
        saved = self.content_block_repository.save(block)
        return self.get_content_block(saved.id)

    def _get_faq_or_404(self, faq_id: str) -> FAQEntry:
        faq = self.faq_repository.get_by_id(faq_id)
        if faq is None:
            raise NotFoundException(
                code='faq_not_found',
                message='FAQ entry was not found.',
            )
        return faq

    def _get_content_block_or_404(self, block_id: str) -> ContentBlock:
        block = self.content_block_repository.get_by_id(block_id)
        if block is None:
            raise NotFoundException(
                code='content_block_not_found',
                message='Content block was not found.',
            )
        return block

    def _ensure_surface_key_available(
        self,
        surface: str,
        key: str,
        *,
        exclude_id: str | None = None,
    ) -> None:
        if self.content_block_repository.surface_key_exists(
            surface=surface,
            key=key,
            exclude_id=exclude_id,
        ):
            raise DomainHTTPException(
                code='content_block_key_taken',
                message='Content block key is already in use for this surface.',
                status_code=422,
                details=[
                    {
                        'field': 'key',
                        'message': 'Content block key is already in use for this surface.',
                    }
                ],
            )

    def _serialize_content_block(self, block: ContentBlock) -> AdminContentBlockResponse:
        return AdminContentBlockResponse(
            id=block.id,
            surface=block.surface,
            key=block.key,
            title=block.title,
            body=block.body,
            cta_label=block.cta_label,
            display_order=block.display_order,
            is_active=block.is_active,
            is_published=block.is_published,
        )
