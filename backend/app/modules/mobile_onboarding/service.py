from __future__ import annotations

from datetime import UTC, datetime

from fastapi import status
from sqlalchemy import select
from sqlalchemy.orm import Session

from ...core.exceptions.http import DomainHTTPException
from ...db.models.mobile_child import MobileChild
from ...db.models.mobile_user import MobileUser
from ..mobile_children.schemas import ChildResponse
from ..mobile_profile.schemas import MobileProfileResponse
from .schemas import OnboardingCompleteRequest, OnboardingCompleteResponse


class MobileOnboardingService:
    def __init__(self, *, session: Session) -> None:
        self._session = session

    def complete(
        self,
        *,
        user: MobileUser,
        payload: OnboardingCompleteRequest,
    ) -> OnboardingCompleteResponse:
        if not payload.privacyConsentAccepted:
            raise DomainHTTPException(
                code='consent_required',
                message='Подтвердите согласие на обработку персональных данных.',
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            )

        locked_user = self._session.scalar(
            select(MobileUser)
            .where(MobileUser.id == user.id)
            .with_for_update()
        )
        if locked_user is None:
            raise DomainHTTPException(
                code='user_not_found',
                message='Профиль пользователя не найден.',
                status_code=status.HTTP_404_NOT_FOUND,
            )

        # A completed request is its own idempotency result. This also makes a
        # retry after a lost response safe and prevents duplicate children.
        if locked_user.onboarding_completed_at is None:
            now = datetime.now(UTC)
            locked_user.first_name = payload.firstName
            locked_user.onboarding_completed_at = now
            locked_user.privacy_consent_at = now
            locked_user.privacy_consent_version = payload.privacyConsentVersion

            existing_children = list(
                self._session.scalars(
                    select(MobileChild)
                    .where(MobileChild.user_id == locked_user.id)
                    .order_by(MobileChild.created_at, MobileChild.id)
                )
            )
            existing_keys = {
                (child.name.strip().casefold(), child.birth_date, child.gender)
                for child in existing_children
            }
            request_keys: set[tuple[str, object, str]] = set()
            for child_payload in payload.children:
                key = (
                    child_payload.name.casefold(),
                    child_payload.birthDate,
                    child_payload.gender.value,
                )
                if key in existing_keys or key in request_keys:
                    continue
                self._session.add(
                    MobileChild(
                        user_id=locked_user.id,
                        name=child_payload.name,
                        birth_date=child_payload.birthDate,
                        gender=child_payload.gender.value,
                    )
                )
                request_keys.add(key)

            self._session.add(locked_user)
            self._session.commit()

        children = list(
            self._session.scalars(
                select(MobileChild)
                .where(MobileChild.user_id == locked_user.id)
                .order_by(MobileChild.created_at, MobileChild.id)
            )
        )
        return OnboardingCompleteResponse(
            onboardingCompleted=locked_user.onboarding_completed_at is not None,
            onboardingCompletedAt=locked_user.onboarding_completed_at,
            privacyConsentAt=locked_user.privacy_consent_at,
            privacyConsentVersion=locked_user.privacy_consent_version,
            profile=MobileProfileResponse.from_user(locked_user),
            children=[ChildResponse.from_model(child) for child in children],
        )
