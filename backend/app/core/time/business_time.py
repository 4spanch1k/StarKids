from datetime import UTC, date, datetime
from zoneinfo import ZoneInfo


BUSINESS_TIMEZONE = ZoneInfo('Asia/Almaty')


def business_today(now: datetime | None = None) -> date:
    """Return today's date in the Boom Bala business timezone."""
    current = now or datetime.now(UTC)
    if current.tzinfo is None:
        current = current.replace(tzinfo=UTC)
    return current.astimezone(BUSINESS_TIMEZONE).date()
