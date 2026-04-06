from sqlalchemy.orm import Session


class Repository:
    def __init__(self, session: Session | None = None) -> None:
        self.session = session

    @property
    def db(self) -> Session:
        if self.session is None:
            raise RuntimeError('Database session is not configured for this repository.')
        return self.session
