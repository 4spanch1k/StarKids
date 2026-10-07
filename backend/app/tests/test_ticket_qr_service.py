import unittest

from app.modules.mobile_payments.ticket_qr_service import TicketQrService


class TicketQrServiceTests(unittest.TestCase):
    def setUp(self) -> None:
        self.service = TicketQrService('s' * 48)

    def test_payload_is_stable_and_verifiable(self) -> None:
        payload = self.service.build_payload('ticket-1')
        self.assertEqual(payload, self.service.build_payload('ticket-1'))
        self.assertEqual(self.service.verify_payload(payload), 'ticket-1')
        self.assertTrue(payload.startswith('bb_ticket:v1:ticket-1:'))

    def test_different_ticket_ids_have_different_payloads(self) -> None:
        self.assertNotEqual(
            self.service.build_payload('ticket-1'),
            self.service.build_payload('ticket-2'),
        )

    def test_modified_id_signature_and_malformed_version_are_invalid(self) -> None:
        payload = self.service.build_payload('ticket-1')
        signature = payload.rsplit(':', 1)[1]
        self.assertIsNone(
            self.service.verify_payload(payload.replace('ticket-1', 'ticket-2'))
        )
        self.assertIsNone(
            self.service.verify_payload(f'bb_ticket:v1:ticket-1:{"0" * len(signature)}')
        )
        self.assertIsNone(self.service.verify_payload('bb_ticket:v2:ticket-1:abc'))
        self.assertIsNone(self.service.verify_payload('not-a-ticket-qr'))

    def test_secret_must_be_strong(self) -> None:
        with self.assertRaises(ValueError):
            TicketQrService('short')

    def test_missing_secret_disables_qr_without_fallback_payload(self) -> None:
        service = TicketQrService(None)
        self.assertFalse(service.is_configured)
        self.assertIsNone(service.verify_payload('bb_ticket:v1:ticket-1:anything'))
        with self.assertRaises(RuntimeError):
            service.build_payload('ticket-1')
