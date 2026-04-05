from fastapi import APIRouter

from .schemas import NotificationItem
from .service import NotificationService

router = APIRouter()
service = NotificationService()


@router.get('/notifications', response_model=list[NotificationItem])
def list_notifications() -> list[NotificationItem]:
    return service.list_notifications()

