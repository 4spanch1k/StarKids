from datetime import UTC, datetime, timedelta
import unittest

from app.modules.visit_segmentation import (
    business_date,
    customer_visit_type,
    days_since_last_visit,
    dormant_cutoff_utc,
)


class VisitSegmentationTests(unittest.TestCase):
    def setUp(self) -> None:
        self.now = datetime(2026, 9, 8, 12, tzinfo=UTC)

    def test_customer_visit_types_are_derived_from_visit_count(self) -> None:
        self.assertEqual(customer_visit_type(0), 'never_visited')
        self.assertEqual(customer_visit_type(1), 'first_visit_only')
        self.assertEqual(customer_visit_type(2), 'returning')

    def test_days_since_last_visit_uses_almaty_calendar_dates(self) -> None:
        self.assertIsNone(days_since_last_visit(None, self.now))
        self.assertEqual(days_since_last_visit(self.now - timedelta(days=29), self.now), 29)
        self.assertEqual(days_since_last_visit(self.now - timedelta(days=30), self.now), 30)
        self.assertEqual(days_since_last_visit(self.now + timedelta(hours=1), self.now), 0)

    def test_dormant_cutoffs_are_calendar_midnights(self) -> None:
        self.assertEqual(business_date(self.now).isoformat(), '2026-09-08')
        self.assertEqual(
            dormant_cutoff_utc(30, self.now).isoformat(),
            '2026-08-09T19:00:00+00:00',
        )
