"""Process due manual push campaigns.

Intended to run from the existing systemd timer once per minute. Delivery rows
are claimed transactionally, so a repeated invocation is safe.
"""

import logging

from app.core.database.session import SessionLocal
from app.modules.admin_push_campaigns.service import PushCampaignService
from app.modules.first_second_visit.service import FirstSecondVisitService
from app.services.push.dependencies import get_push_delivery

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


def main() -> None:
    session = SessionLocal()
    try:
        delivery = get_push_delivery()
        service = PushCampaignService(session, delivery)
        lifecycle = FirstSecondVisitService(session, service)
        eligible = lifecycle.process()
        processed = service.process_due()
        logger.info('processed first-to-second-visit executions=%s push campaigns=%s', eligible, processed)
    finally:
        session.close()


if __name__ == '__main__':
    main()
