from sqlalchemy.orm import Session


class Repository:
    def __init__(self, session: Session | None = None) -> None:
        self.session = session

