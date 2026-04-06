from fastapi import HTTPException, status


class DomainHTTPException(HTTPException):
    def __init__(
        self,
        *,
        code: str,
        message: str,
        status_code: int = status.HTTP_400_BAD_REQUEST,
        details: list[dict[str, str | None]] | None = None,
    ) -> None:
        self.code = code
        self.message = message
        self.details = details or []
        super().__init__(status_code=status_code, detail=message)


class NotFoundException(DomainHTTPException):
    def __init__(
        self,
        *,
        code: str,
        message: str,
        details: list[dict[str, str | None]] | None = None,
    ) -> None:
        super().__init__(
            code=code,
            message=message,
            status_code=status.HTTP_404_NOT_FOUND,
            details=details,
        )
