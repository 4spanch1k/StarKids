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

    def get_latest_active_for_phone(self, phone: str) -> MobileOtpChallenge | None:
        return self.db.scalar(
            select(MobileOtpChallenge)
            .where(
                MobileOtpChallenge.phone == phone,
                MobileOtpChallenge.consumed_at.is_(None),
            )
            .order_by(MobileOtpChallenge.created_at.desc())
            .limit(1)
        )

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

    def consume_if_active(
        self,
        verification_id: str,
        *,
        consumed_at: datetime,
    ) -> bool:
        """Consume only the challenge created by the failed delivery attempt.

        The conditional predicate prevents a late provider failure from
        consuming a newer challenge created by a subsequent request.
        """

        result = self.db.execute(
            update(MobileOtpChallenge)
            .where(
                MobileOtpChallenge.id == verification_id,
                MobileOtpChallenge.consumed_at.is_(None),
            )
            .values(consumed_at=consumed_at)
        )
        return result.rowcount == 1
