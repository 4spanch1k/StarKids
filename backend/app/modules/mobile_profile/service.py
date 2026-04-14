from __future__ import annotations

from uuid import uuid4

from fastapi import status

from ...core.exceptions.http import DomainHTTPException
from ...core.storage.backend import StorageBackend
from ...db.models.mobile_user import MobileUser
from ...db.repositories.mobile_request_history_repository import MobileRequestHistoryRepository
from ...db.repositories.mobile_user_repository import MobileUserRepository
from ..mobile_request_history.schemas import (
    MobileRequestHistoryBranchSummary,
    MobileRequestHistoryPackageSummary,
)
from .schemas import (
    MobileAvatarUploadResponse,
    MobileProfileRequestItem,
    MobileProfileRequestListResponse,
    MobileProfileResponse,
    MobileProfileUpdateRequest,
)

_MIME_TO_EXT = {
    'jpeg': 'jpg',
    'png': 'png',
    'webp': 'webp',
}
_ALLOWED_IMAGE_TYPES = {'jpeg', 'png', 'webp'}

# Magic-byte signatures — replaces deprecated imghdr
_IMAGE_SIGNATURES: list[tuple[bytes, str]] = [
    (b'\xff\xd8\xff', 'jpeg'),
    (b'\x89PNG\r\n\x1a\n', 'png'),
    (b'RIFF', 'webp'),  # also check bytes 8-12 == WEBP below
]


def _detect_image_type(data: bytes) -> str | None:
    if data[:3] == b'\xff\xd8\xff':
        return 'jpeg'
    if data[:8] == b'\x89PNG\r\n\x1a\n':
        return 'png'
    if data[:4] == b'RIFF' and data[8:12] == b'WEBP':
        return 'webp'
    return None


class MobileProfileService:
    def __init__(
        self,
        *,
        user_repository: MobileUserRepository,
        request_history_repository: MobileRequestHistoryRepository,
        storage: StorageBackend,
        settings,
    ) -> None:
        self._user_repository = user_repository
        self._request_history_repository = request_history_repository
        self._storage = storage
        self._settings = settings

    def get_profile(self, user: MobileUser) -> MobileProfileResponse:
        return MobileProfileResponse.from_user(user)

    def update_profile(
        self,
        user: MobileUser,
        payload: MobileProfileUpdateRequest,
    ) -> MobileProfileResponse:
        fields_set = payload.model_fields_set
        kwargs: dict = {}

        if 'firstName' in fields_set:
            kwargs['first_name'] = payload.firstName
        if 'lastName' in fields_set:
            kwargs['last_name'] = payload.lastName
        if 'email' in fields_set:
            new_email = str(payload.email).lower().strip() if payload.email is not None else None
            if new_email is not None and new_email != (user.email or ''):
                existing = self._user_repository.find_by_email(new_email)
                if existing is not None and existing.id != user.id:
                    raise DomainHTTPException(
                        code='email_already_in_use',
                        message='Email is already used by another account.',
                        status_code=status.HTTP_409_CONFLICT,
                        details=[{'field': 'email', 'message': 'Этот email уже используется.'}],
                    )
            kwargs['email'] = new_email
        if 'childBirthDate' in fields_set:
            kwargs['child_birth_date'] = payload.childBirthDate

        if kwargs:
            user = self._user_repository.update(user, **kwargs)

        return MobileProfileResponse.from_user(user)

    def upload_avatar(
        self,
        user: MobileUser,
        content_type: str,
        data: bytes,
    ) -> MobileAvatarUploadResponse:
        if not data:
            raise DomainHTTPException(
                code='invalid_avatar',
                message='Avatar file is empty.',
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            )

        if len(data) > self._settings.max_avatar_size_bytes:
            raise DomainHTTPException(
                code='invalid_avatar',
                message='Avatar file is too large.',
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            )

        detected = _detect_image_type(data)
        if detected not in _ALLOWED_IMAGE_TYPES:
            raise DomainHTTPException(
                code='invalid_avatar',
                message='Only JPEG, PNG and WebP images are allowed.',
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            )

        ext = _MIME_TO_EXT.get(detected, detected)
        storage_key = f'avatars/{user.id}/{uuid4().hex}.{ext}'

        if user.avatar_url is not None:
            old_key = self._extract_storage_key(user.avatar_url)
            if old_key:
                self._storage.delete(old_key)

        stored = self._storage.save(data, storage_key, content_type)
        self._user_repository.update(user, avatar_url=stored.url)

        return MobileAvatarUploadResponse(avatarUrl=stored.url)

    def delete_avatar(self, user: MobileUser) -> MobileProfileResponse:
        if user.avatar_url is not None:
            old_key = self._extract_storage_key(user.avatar_url)
            if old_key:
                self._storage.delete(old_key)
        user = self._user_repository.update(user, avatar_url=None)
        return MobileProfileResponse.from_user(user)

    def list_requests(
        self,
        user_id: str,
        limit: int,
        offset: int,
    ) -> MobileProfileRequestListResponse:
        records = self._request_history_repository.list_for_mobile_user(user_id)
        total = len(records)
        page = records[offset: offset + limit]
        items = [
            MobileProfileRequestItem(
                id=record.id,
                type=record.type,
                status=record.status,
                createdAt=record.created_at,
                requestedDate=record.requested_date,
                guestCount=record.guest_count,
                notes=record.notes,
                branch=(
                    MobileRequestHistoryBranchSummary(
                        id=record.branch_id,
                        name=record.branch_name,
                        shortLabel=record.branch_short_label,
                    )
                    if record.branch_id is not None
                    and record.branch_name is not None
                    and record.branch_short_label is not None
                    else None
                ),
                package=(
                    MobileRequestHistoryPackageSummary(
                        id=record.birthday_package_id,
                        name=record.birthday_package_name,
                    )
                    if record.birthday_package_id is not None
                    and record.birthday_package_name is not None
                    else None
                ),
            )
            for record in page
        ]
        return MobileProfileRequestListResponse(
            items=items,
            total=total,
            limit=limit,
            offset=offset,
        )

    def _extract_storage_key(self, url: str) -> str | None:
        prefix = self._settings.normalized_media_url_prefix + '/'
        if self._settings.public_base_url:
            full_prefix = self._settings.public_base_url.rstrip('/') + prefix
            if url.startswith(full_prefix):
                return url[len(full_prefix):]
        if self._settings.storage_backend.lower() == 'local':
            idx = url.find(prefix)
            if idx != -1:
                return url[idx + len(prefix):]
        return None
