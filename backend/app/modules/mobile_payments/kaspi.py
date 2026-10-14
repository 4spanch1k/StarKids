from __future__ import annotations

from decimal import Decimal, InvalidOperation
from ipaddress import IPv4Address, IPv6Address, ip_address
from urllib.parse import urlencode

from ...core.config.settings import Settings


class KaspiProtocolError(ValueError):
    pass


def build_kaspi_payment_url(
    *,
    settings: Settings,
    local_order_id: str,
    cash_amount_tenge: int,
) -> str:
    if not settings.is_kaspi_configured:
        raise KaspiProtocolError('Kaspi configuration is incomplete')
    if cash_amount_tenge <= 0:
        raise KaspiProtocolError('Kaspi amount must be positive')
    query = urlencode(
        {
            'service_id': settings.kaspi_service_id,
            settings.kaspi_account_parameter_id: local_order_id,
            'amount': f'{cash_amount_tenge:.2f}',
        }
    )
    return f'https://kaspi.kz/pay/{settings.kaspi_service_name}?{query}'


def parse_kaspi_amount(value: str | None) -> Decimal:
    try:
        amount = Decimal((value or '').strip())
    except InvalidOperation as exc:
        raise KaspiProtocolError('Invalid Kaspi amount') from exc
    if not amount.is_finite() or amount < 0:
        raise KaspiProtocolError('Invalid Kaspi amount')
    return amount.quantize(Decimal('0.01'))


def is_kaspi_source_allowed(
    source_ip: str | None,
    allowed_networks: tuple[object, ...],
) -> bool:
    try:
        address: IPv4Address | IPv6Address = ip_address((source_ip or '').strip())
    except ValueError:
        return False
    return any(address in network for network in allowed_networks)


def kaspi_response(
    *,
    result: int,
    comment: str,
    txn_id: str,
    provider_transaction_reference: str | None = None,
    amount: int | None = None,
) -> str:
    values = [
        '<response>',
        f'<result>{result}</result>',
        f'<comment>{_xml_escape(comment)}</comment>',
        f'<txn_id>{_xml_escape(txn_id)}</txn_id>',
    ]
    if provider_transaction_reference is not None:
        values.append(f'<prv_txn>{_xml_escape(provider_transaction_reference)}</prv_txn>')
    if amount is not None:
        values.append(f'<sum>{amount:.2f}</sum>')
    values.append('</response>')
    return ''.join(values)


def _xml_escape(value: str) -> str:
    return (
        str(value).replace('&', '&amp;')
        .replace('<', '&lt;').replace('>', '&gt;')
        .replace('"', '&quot;').replace("'", '&apos;')
    )
