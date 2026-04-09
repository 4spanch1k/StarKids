from datetime import UTC, datetime

from sqlalchemy import or_, select

from ..models.mobile_notification_device import MobileNotificationDevice
from .base import Repository


class MobileNotificationDeviceRepository(Repository):
    def get_by_mobile_session_id(
        self,
        mobile_session_id: str,
    ) -> MobileNotificationDevice | None:
        return self.db.scalar(
            select(MobileNotificationDevice).where(
                MobileNotificationDevice.mobile_session_id == mobile_session_id,
            )
        )

    def upsert(
        self,
        *,
        mobile_user_id: str,
        mobile_session_id: str,
        platform: str,
        push_token: str,
        permission_status: str,
        notifications_enabled: bool,
    ) -> MobileNotificationDevice:
        matches = self.db.scalars(
            select(MobileNotificationDevice).where(
                or_(
                    MobileNotificationDevice.mobile_session_id == mobile_session_id,
                    MobileNotificationDevice.push_token == push_token,
                )
            )
        ).all()

        session_match = next(
            (
                device
                for device in matches
                if device.mobile_session_id == mobile_session_id
            ),
            None,
        )
        token_match = next(
            (
                device
                for device in matches
                if device.push_token == push_token
            ),
            None,
        )
        device = session_match or token_match

        if device is not None:
            duplicates = [
                match for match in matches if match.id != device.id
            ]
            for duplicate in duplicates:
                self.db.delete(duplicate)
            if duplicates:
                self.db.flush()

        now = datetime.now(UTC)
        if device is None:
            device = MobileNotificationDevice(
                mobile_user_id=mobile_user_id,
                mobile_session_id=mobile_session_id,
                platform=platform,
                push_token=push_token,
                permission_status=permission_status,
                notifications_enabled=notifications_enabled,
                created_at=now,
                updated_at=now,
            )
        else:
            device.mobile_user_id = mobile_user_id
            device.mobile_session_id = mobile_session_id
            device.platform = platform
            device.push_token = push_token
            device.permission_status = permission_status
            device.notifications_enabled = notifications_enabled
            device.updated_at = now

        self.db.add(device)
        self.db.commit()
        self.db.refresh(device)
        return device

    def delete_for_mobile_session(self, mobile_session_id: str) -> bool:
        device = self.get_by_mobile_session_id(mobile_session_id)
        if device is None:
            return False

        self.db.delete(device)
        self.db.commit()
        return True
