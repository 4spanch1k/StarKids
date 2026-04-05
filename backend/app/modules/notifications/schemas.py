from pydantic import BaseModel


class NotificationItem(BaseModel):
    id: str
    title: str
    is_read: bool

