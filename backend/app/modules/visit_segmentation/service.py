from __future__ import annotations

from datetime import UTC, date, datetime, time, timedelta
from typing import Literal
from zoneinfo import ZoneInfo

from sqlalchemy import Select, and_, func, select

from ...db.models.visit import Visit

BUSINESS_TIMEZONE = ZoneInfo('Asia/Almaty')
CustomerVisitType = Literal['never_visited', 'first_visit_only', 'returning']
VisitAudienceSegment = Literal[
    'never_visited',
    'first_visit_only',
    'returning',
    'dormant_30',
    'dormant_60',
    'dormant_90',
]


def _as_utc(value: datetime) -> datetime:
    normalized = value if value.tzinfo is not None else value.replace(tzinfo=UTC)
    return normalized.astimezone(UTC)


def business_date(now: datetime | None = None) -> date:
    """Return the authoritative business calendar date for visit thresholds."""
    return _as_utc(now or datetime.now(UTC)).astimezone(BUSINESS_TIMEZONE).date()


def days_since_last_visit(last_visit_at: datetime | None, now: datetime | None = None) -> int | None:
    if last_visit_at is None:
        return None
    value = (business_date(now) - _as_utc(last_visit_at).astimezone(BUSINESS_TIMEZONE).date()).days
    return max(0, value)


def customer_visit_type(visit_count: int) -> CustomerVisitType:
    if visit_count <= 0:
        return 'never_visited'
    if visit_count == 1:
        return 'first_visit_only'
    return 'returning'


def dormant_cutoff_utc(days: int, now: datetime | None = None) -> datetime:
    """Return the exclusive UTC boundary after the threshold calendar date."""
    cutoff_date = business_date(now) - timedelta(days=days) + timedelta(days=1)
    local_midnight = datetime.combine(cutoff_date, time.min, tzinfo=BUSINESS_TIMEZONE)
    return local_midnight.astimezone(UTC)


def visit_stats_subquery():
    """Set-based authoritative visit stats, with no lifecycle persistence."""
    return (
        select(
            Visit.mobile_user_id.label('user_id'),
            func.count(Visit.id).label('visit_count'),
            func.min(Visit.started_at).label('first_visit_at'),
            func.max(Visit.started_at).label('last_visit_at'),
        )
        .group_by(Visit.mobile_user_id)
        .subquery()
    )


def visit_segment_predicate(stats, segment: VisitAudienceSegment, now: datetime | None = None):
    """Build a predicate against a visit stats aggregate subquery."""
    visit_count = func.coalesce(stats.c.visit_count, 0)
    if segment == 'never_visited':
        return visit_count == 0
    if segment == 'first_visit_only':
        return visit_count == 1
    if segment == 'returning':
        return visit_count >= 2

    days = int(segment.removeprefix('dormant_'))
    return and_(
        visit_count >= 1,
        stats.c.last_visit_at < dormant_cutoff_utc(days, now),
    )


def visit_segment_user_ids(segment: VisitAudienceSegment, now: datetime | None = None) -> Select:
    """Return a reusable set-based user-id query for push audience resolution."""
    from ...db.models.mobile_user import MobileUser

    stats = visit_stats_subquery()
    return (
        select(MobileUser.id)
        .outerjoin(stats, stats.c.user_id == MobileUser.id)
        .where(visit_segment_predicate(stats, segment, now))
    )
