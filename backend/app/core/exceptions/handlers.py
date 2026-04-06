from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from starlette.exceptions import HTTPException as StarletteHTTPException

from .http import DomainHTTPException

BIRTHDAY_LEAD_PATH = '/api/v1/mobile/leads/birthday'


def _error_payload(
    *,
    code: str,
    message: str,
    details: list[dict[str, str | None]] | None = None,
) -> dict[str, object]:
    return {
        'error': {
            'code': code,
            'message': message,
            'details': details or [],
        }
    }


def _is_birthday_lead_request(request: Request) -> bool:
    return request.method == 'POST' and request.url.path == BIRTHDAY_LEAD_PATH


def _group_errors(
    details: list[dict[str, str | None]] | None,
) -> dict[str, list[str]]:
    grouped: dict[str, list[str]] = {}
    for detail in details or []:
        field = detail.get('field') or 'request'
        message = detail.get('message')
        if message is None:
            continue
        grouped.setdefault(field, []).append(message)
    return grouped


def _map_birthday_lead_validation_message(
    field: str,
    error_type: str,
) -> str:
    if field == 'name':
        return 'Введите имя'
    if field == 'phone':
        if error_type == 'missing':
            return 'Введите номер телефона'
        return 'Введите корректный номер'
    if field == 'branchId':
        return 'Выберите филиал'
    if field == 'packageId':
        return 'Выберите корректный пакет'
    if field == 'preferredDate':
        if error_type == 'missing':
            return 'Укажите дату'
        return 'Укажите корректную дату'
    if field == 'guestCount':
        return 'Укажите корректное количество гостей'
    if field == 'comment':
        return 'Комментарий слишком длинный'
    return 'Проверьте введенные данные'


def _birthday_lead_validation_details(
    exc: RequestValidationError,
) -> list[dict[str, str]]:
    details: list[dict[str, str]] = []
    for error in exc.errors():
        field = next(
            (
                str(part)
                for part in reversed(error['loc'])
                if isinstance(part, str) and part != 'body'
            ),
            'request',
        )
        details.append(
            {
                'field': field,
                'message': _map_birthday_lead_validation_message(
                    field,
                    error['type'],
                ),
            }
        )
    return details


def _birthday_lead_error_payload(
    *,
    message: str,
    details: list[dict[str, str | None]] | None = None,
) -> dict[str, object]:
    return {
        'message': message,
        'errors': _group_errors(details),
    }


async def domain_http_exception_handler(
    request: Request,
    exc: DomainHTTPException,
) -> JSONResponse:
    if _is_birthday_lead_request(request):
        return JSONResponse(
            status_code=exc.status_code,
            content=_birthday_lead_error_payload(
                message='Validation error',
                details=exc.details,
            ),
        )
    return JSONResponse(
        status_code=exc.status_code,
        content=_error_payload(
            code=exc.code,
            message=exc.message,
            details=exc.details,
        ),
    )


async def http_exception_handler(
    _: Request,
    exc: StarletteHTTPException,
) -> JSONResponse:
    message = exc.detail if isinstance(exc.detail, str) else 'Request failed.'
    return JSONResponse(
        status_code=exc.status_code,
        content=_error_payload(
            code='http_error',
            message=message,
        ),
    )


async def validation_exception_handler(
    request: Request,
    exc: RequestValidationError,
) -> JSONResponse:
    details = [
        {
            'field': '.'.join(str(part) for part in error['loc'] if part != 'body'),
            'message': error['msg'],
        }
        for error in exc.errors()
    ]
    if _is_birthday_lead_request(request):
        return JSONResponse(
            status_code=422,
            content=_birthday_lead_error_payload(
                message='Validation error',
                details=_birthday_lead_validation_details(exc),
            ),
        )
    return JSONResponse(
        status_code=422,
        content=_error_payload(
            code='validation_error',
            message='Request validation failed.',
            details=details,
        ),
    )


def register_exception_handlers(app: FastAPI) -> None:
    app.add_exception_handler(DomainHTTPException, domain_http_exception_handler)
    app.add_exception_handler(StarletteHTTPException, http_exception_handler)
    app.add_exception_handler(
        RequestValidationError,
        validation_exception_handler,
    )
    app.add_exception_handler(Exception, unexpected_exception_handler)


async def unexpected_exception_handler(
    request: Request,
    _: Exception,
) -> JSONResponse:
    if _is_birthday_lead_request(request):
        return JSONResponse(
            status_code=500,
            content={'message': 'Не удалось отправить заявку'},
        )
    return JSONResponse(
        status_code=500,
        content=_error_payload(
            code='internal_server_error',
            message='Internal server error.',
        ),
    )
