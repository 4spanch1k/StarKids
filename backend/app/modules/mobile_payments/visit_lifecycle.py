from __future__ import annotations

import re
from datetime import UTC, date, datetime, time, timedelta

from ...core.time.business_time import BUSINESS_TIMEZONE
from ...db.models.branch import Branch
from ...db.models.visit import Visit

_HOURS_RE = re.compile(r"(\d{1,2}):(\d{2})\s*[-–—]\s*(\d{1,2}):(\d{2})")


def visit_validity_cutoff(*, visit_date: date, branch: Branch) -> datetime:
    """Return the end of the purchased admission day in branch local time.

    Entry tickets are date-bound in the current domain. Branch working hours
    are the only operational validity window available, so completion is
    derived from those hours rather than an arbitrary duration.
    """
    match = _HOURS_RE.search(branch.working_hours or '')
    if match is None:
        # A malformed schedule must fail closed at the end of the local day,
        # never leave an ACTIVE visit forever.
        return datetime.combine(
            visit_date + timedelta(days=1), time.min, tzinfo=BUSINESS_TIMEZONE
        )
    start_hour, start_minute, end_hour, end_minute = (
        int(match.group(index)) for index in range(1, 5)
    )
    end_date = visit_date + (timedelta(days=1) if (end_hour, end_minute) <= (start_hour, start_minute) else timedelta())
    return datetime.combine(
        end_date,
        time(hour=min(end_hour, 23), minute=min(end_minute, 59)),
        tzinfo=BUSINESS_TIMEZONE,
    )


def should_complete_visit(*, visit: Visit, payment_visit_date: date | None, branch: Branch | None, now: datetime) -> bool:
    if visit.status != 'active' or payment_visit_date is None or branch is None:
        return False
    normalized_now = now if now.tzinfo is not None else now.replace(tzinfo=UTC)
    return normalized_now.astimezone(BUSINESS_TIMEZONE) >= visit_validity_cutoff(
        visit_date=payment_visit_date,
        branch=branch,
    )
