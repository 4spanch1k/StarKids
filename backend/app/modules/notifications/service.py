from .schemas import NotificationItem


class NotificationService:
    def list_notifications(self) -> list[NotificationItem]:
        return [
            NotificationItem(
                id='notification-1',
                title='Welcome to Star Kids',
                is_read=False,
            )
        ]

