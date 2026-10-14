"""Generate and resume automatic birthday reminders once per day."""

import logging

from app.core.database.session import SessionLocal
from app.modules.admin_push_campaigns.service import PushCampaignService
from app.modules.birthday_reminders.service import BirthdayReminderService
from app.services.push.dependencies import get_push_delivery

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


def main() -> None:
    session = SessionLocal()
    try:
        service = BirthdayReminderService(
            session,
            PushCampaignService(session, get_push_delivery()),
        )
        processed = service.process()
        logger.info('processed birthday reminders=%s', processed)
    finally:
        session.close()


if __name__ == '__main__':
    main()
