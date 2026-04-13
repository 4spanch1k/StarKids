from __future__ import annotations

from dataclasses import dataclass
import logging
from secrets import token_hex
from typing import Protocol
from urllib import parse, request
from urllib.error import URLError
from xml.etree import ElementTree

from ...core.config.settings import Settings
from .signing import build_freedompay_signature, verify_freedompay_signature

logger = logging.getLogger(__name__)

INIT_PAYMENT_SCRIPT = 'init_payment.php'


class FreedomPayGatewayError(RuntimeError):
    pass


@dataclass(frozen=True)
class FreedomPayInitResult:
    external_payment_id: str
    payment_url: str
    raw_payload: dict[str, str]


class FreedomPayClientProtocol(Protocol):
    def init_payment(self, params: dict[str, object]) -> FreedomPayInitResult:
        ...


class FreedomPayClient:
    def __init__(self, settings: Settings) -> None:
        self._settings = settings

    def init_payment(self, params: dict[str, object]) -> FreedomPayInitResult:
        if self._settings.freedompay_mock_mode:
            return self._mock_init_payment(params)

        if not self._settings.is_freedompay_configured:
            raise FreedomPayGatewayError('Freedom Pay credentials are not configured.')

        signed_params = dict(params)
        signed_params['pg_sig'] = build_freedompay_signature(
            script_name=INIT_PAYMENT_SCRIPT,
            params=signed_params,
            secret_key=self._settings.freedompay_secret_key or '',
        )
        endpoint = f"{self._settings.freedompay_base_url.rstrip('/')}/{INIT_PAYMENT_SCRIPT}"
        body = parse.urlencode(signed_params).encode('utf-8')
        gateway_request = request.Request(
            endpoint,
            data=body,
            headers={
                'Content-Type': 'application/x-www-form-urlencoded',
                'Accept': 'application/xml',
            },
            method='POST',
        )

        try:
            with request.urlopen(  # noqa: S310 - endpoint is merchant-configured.
                gateway_request,
                timeout=self._settings.freedompay_request_timeout_seconds,
            ) as response:
                raw_body = response.read().decode('utf-8')
        except URLError as exc:
            logger.exception('Freedom Pay init request failed.')
            raise FreedomPayGatewayError('Freedom Pay init request failed.') from exc

        payload = _parse_xml_payload(raw_body)
        if payload.get('pg_sig') and not verify_freedompay_signature(
            script_name=INIT_PAYMENT_SCRIPT,
            params=payload,
            secret_key=self._settings.freedompay_secret_key or '',
        ):
            raise FreedomPayGatewayError('Freedom Pay init response signature is invalid.')

        if payload.get('pg_status') != 'ok':
            raise FreedomPayGatewayError(
                payload.get('pg_error_description')
                or payload.get('pg_description')
                or 'Freedom Pay rejected payment initialization.'
            )

        external_payment_id = payload.get('pg_payment_id')
        payment_url = payload.get('pg_redirect_url')
        if not external_payment_id or not payment_url:
            raise FreedomPayGatewayError('Freedom Pay init response is incomplete.')

        return FreedomPayInitResult(
            external_payment_id=external_payment_id,
            payment_url=payment_url,
            raw_payload=payload,
        )

    def _mock_init_payment(self, params: dict[str, object]) -> FreedomPayInitResult:
        order_id = str(params.get('pg_order_id') or token_hex(8))
        return FreedomPayInitResult(
            external_payment_id=f'mock-{order_id}',
            payment_url=f'https://example.com/freedompay/mock-payment?order={parse.quote(order_id)}',
            raw_payload={
                'pg_status': 'ok',
                'pg_payment_id': f'mock-{order_id}',
                'pg_redirect_url': f'https://example.com/freedompay/mock-payment?order={parse.quote(order_id)}',
                'pg_redirect_url_type': 'need data',
                'pg_mock_mode': '1',
            },
        )


def _parse_xml_payload(raw_body: str) -> dict[str, str]:
    try:
        root = ElementTree.fromstring(raw_body)
    except ElementTree.ParseError as exc:
        raise FreedomPayGatewayError('Freedom Pay response is not valid XML.') from exc

    payload: dict[str, str] = {}
    for child in root:
        payload[child.tag] = child.text or ''
    return payload
