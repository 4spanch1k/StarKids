from ...db.repositories.mobile_notification_device_repository import (
    MobileNotificationDeviceRepository,
)
from .delivery_port import PushDeliveryPort
from .delivery_result import PushDeliveryResult


class PushService:
    """
    Orchestrates push delivery to users and groups of users.

    Fetches active device tokens from the repository and delegates
    individual delivery to the injected :class:`PushDeliveryPort`.

    Event trigger points (wired in feature module services):
    - Birthday request received → :meth:`notify_birthday_request_received`
    - Request status changed   → :meth:`notify_request_status_changed`
    - New promotion published   → :meth:`notify_promotion_published`
    """

    def __init__(
        self,
        *,
        delivery: PushDeliveryPort,
        device_repository: MobileNotificationDeviceRepository,
    ) -> None:
        self._delivery = delivery
        self._device_repository = device_repository

    def send_to_device(
        self,
        *,
        device_token: str,
        title: str,
        body: str,
        data: dict[str, str] | None = None,
    ) -> PushDeliveryResult:
        """Send a notification to a single known FCM device token."""
        return self._delivery.send(
            device_token=device_token,
            title=title,
            body=body,
            data=data,
        )

    def send_to_user(
        self,
        *,
        user_id: str,
        title: str,
        body: str,
        data: dict[str, str] | None = None,
    ) -> list[PushDeliveryResult]:
        """
        Send a notification to all active devices registered by a user.

        Returns one result per device.  An empty list means the user has no
        registered devices (no error is raised in that case).
        """
        devices = self._device_repository.get_active_devices_for_user(user_id)
        return [
            self._delivery.send(
                device_token=device.push_token,
                title=title,
                body=body,
                data=data,
            )
            for device in devices
        ]

    def send_to_users(
        self,
        *,
        user_ids: list[str],
        title: str,
        body: str,
        data: dict[str, str] | None = None,
    ) -> list[PushDeliveryResult]:
        """Send a notification to all active devices of multiple users."""
        results: list[PushDeliveryResult] = []
        for user_id in user_ids:
            results.extend(
                self.send_to_user(
                    user_id=user_id,
                    title=title,
                    body=body,
                    data=data,
                )
            )
        return results

    # ---------------------------------------------------------------------------
    # Named event trigger points
    # ---------------------------------------------------------------------------

    def notify_birthday_request_received(
        self,
        *,
        admin_user_ids: list[str],
        branch_name: str,
        parent_name: str,
    ) -> list[PushDeliveryResult]:
        """
        Triggered after a birthday request is successfully created.

        Currently notifies admin/staff users for the given branch.
        When mobile staff accounts are available, pass their user IDs here.
        """
        return self.send_to_users(
            user_ids=admin_user_ids,
            title='Новая заявка на день рождения',
            body=f'{parent_name} оставил(а) заявку в {branch_name}.',
            data={'event': 'birthday_request_received'},
        )

    def notify_request_status_changed(
        self,
        *,
        user_id: str,
        request_type: str,
        new_status: str,
    ) -> list[PushDeliveryResult]:
        """
        Triggered when the status of a mobile user's request changes.

        Wire this from the admin module that updates request status.
        """
        return self.send_to_user(
            user_id=user_id,
            title='Статус заявки изменился',
            body=f'Ваша заявка ({request_type}) обновлена: {new_status}.',
            data={'event': 'request_status_changed', 'status': new_status},
        )

    def notify_promotion_published(
        self,
        *,
        user_ids: list[str],
        promotion_title: str,
    ) -> list[PushDeliveryResult]:
        """
        Triggered when a promotion is published in the admin panel.

        Pass the IDs of all users who should receive the campaign,
        or implement a batch query outside this method for large audiences.
        """
        return self.send_to_users(
            user_ids=user_ids,
            title='Новая акция',
            body=promotion_title,
            data={'event': 'promotion_published'},
        )
