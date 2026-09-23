from datetime import UTC, datetime

from sqlalchemy import select

from ..models.admin_session import AdminSession
from .base import Repository


class AdminSessionRepository(Repository):
    def get_by_id(self, session_id: str) -> AdminSession | None:
        return self.db.scalar(select(AdminSession).where(AdminSession.id == session_id))

    def create(
        self,
        *,
        session_id: str,
        admin_user_id: str,
        refresh_token_hash: str,
        expires_at: datetime,
    ) -> AdminSession:
        session = AdminSession(
            id=session_id,
            admin_user_id=admin_user_id,
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
        session: AdminSession,
        *,
        refresh_token_hash: str,
        expires_at: datetime,
    ) -> AdminSession:
        session.refresh_token_hash = refresh_token_hash
        session.expires_at = expires_at
        session.last_used_at = datetime.now(UTC)
        session.revoked_at = None
        self.db.add(session)
        self.db.commit()
        self.db.refresh(session)
        return session

    def revoke(self, session: AdminSession) -> AdminSession:
        session.revoked_at = datetime.now(UTC)
        session.last_used_at = datetime.now(UTC)
        self.db.add(session)
        self.db.commit()
        self.db.refresh(session)
        return session
