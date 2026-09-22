from datetime import UTC, datetime

from sqlalchemy import select

from ..models.mobile_session import MobileSession
from .base import Repository


class MobileSessionRepository(Repository):
    def get_by_id(self, session_id: str) -> MobileSession | None:
        return self.db.scalar(select(MobileSession).where(MobileSession.id == session_id))

    def get_by_id_for_update(self, session_id: str) -> MobileSession | None:
        """Load one session while holding its row lock for a mutation flow."""
        return self.db.scalar(
            select(MobileSession)
            .where(MobileSession.id == session_id)
            .with_for_update()
        )

    def create(
        self,
        *,
        session_id: str,
        mobile_user_id: str,
        refresh_token_hash: str,
        expires_at: datetime,
    ) -> MobileSession:
        session = MobileSession(
            id=session_id,
            mobile_user_id=mobile_user_id,
            refresh_token_hash=refresh_token_hash,
            expires_at=expires_at,
            last_used_at=datetime.now(UTC),
        )
        self.db.add(session)
        self.db.commit()
        self.db.refresh(session)
        return session

    def rotate_refresh_token(
        self,
        session: MobileSession,
        *,
        refresh_token_hash: str,
        expires_at: datetime,
    ) -> MobileSession:
        session.refresh_token_hash = refresh_token_hash
        session.expires_at = expires_at
        session.last_used_at = datetime.now(UTC)
        session.revoked_at = None
        self.db.add(session)
        self.db.commit()
        self.db.refresh(session)
        return session

    def rotate_refresh_token_in_transaction(
        self,
        session: MobileSession,
        *,
        refresh_token_hash: str,
        expires_at: datetime,
    ) -> MobileSession:
        """Apply refresh rotation without committing the caller's transaction."""
        session.refresh_token_hash = refresh_token_hash
        session.expires_at = expires_at
        session.last_used_at = datetime.now(UTC)
        session.revoked_at = None
        self.db.add(session)
        return session

    def revoke(self, session: MobileSession) -> MobileSession:
        session.revoked_at = datetime.now(UTC)
        session.last_used_at = datetime.now(UTC)
        self.db.add(session)
        self.db.commit()
        self.db.refresh(session)
        return session
