from datetime import datetime

from sqlalchemy import select, update

from ..models.mobile_otp_challenge import MobileOtpChallenge
from .base import Repository


class MobileOtpChallengeRepository(Repository):
    def invalidate_active_for_phone(self, phone: str, *, consumed_at: datetime) -> None:
        self.db.execute(
            update(MobileOtpChallenge)
            .where(
                MobileOtpChallenge.phone == phone,
                MobileOtpChallenge.consumed_at.is_(None),
            )
            .values(consumed_at=consumed_at)
        )

    def create(
        self,
        *,
        verification_id: str,
        phone: str,
        code_hash: str,
        expires_at: datetime,
        max_attempts: int,
    ) -> MobileOtpChallenge:
        challenge = MobileOtpChallenge(
            id=verification_id,
            phone=phone,
            code_hash=code_hash,
            expires_at=expires_at,
            max_attempts=max_attempts,
        )
        self.db.add(challenge)
        return challenge

    def get_for_update(
        self,
        verification_id: str,
        *,
        phone: str,
    ) -> MobileOtpChallenge | None:
        return self.db.scalar(
            select(MobileOtpChallenge)
            .where(
                MobileOtpChallenge.id == verification_id,
                MobileOtpChallenge.phone == phone,
            )
            .with_for_update()
        )
