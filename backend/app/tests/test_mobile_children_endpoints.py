from __future__ import annotations

import unittest
from datetime import date

from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from app.core.database.session import get_db_session
from app.db.models import Base
from app.db.models.mobile_session import MobileSession
from app.db.models.mobile_user import MobileUser
from app.main import app
from app.modules.mobile_children.dependencies import get_mobile_children_service
from app.modules.mobile_children.service import MobileChildrenService
from app.db.repositories.mobile_child_repository import MobileChildRepository


class MobileChildrenEndpointTests(unittest.TestCase):
    """Integration tests for /mobile/me/children CRUD endpoints."""

    @classmethod
    def setUpClass(cls) -> None:
        cls.engine = create_engine(
            'sqlite://',
            connect_args={'check_same_thread': False},
            poolclass=StaticPool,
        )
        cls.SessionLocal = sessionmaker(
            bind=cls.engine,
            autoflush=False,
            autocommit=False,
            expire_on_commit=False,
            class_=Session,
        )
        Base.metadata.create_all(cls.engine)

        def override_get_db_session():
            session = cls.SessionLocal()
            try:
                yield session
            finally:
                session.close()

        def override_children_service(session: Session = get_db_session):  # type: ignore[assignment]
            pass  # replaced below

        from fastapi import Depends
        from sqlalchemy.orm import Session as _Session
        from app.core.database.session import get_db_session as _get_db

        def _override_children_service(session: _Session = Depends(_get_db)):
            return MobileChildrenService(
                child_repository=MobileChildRepository(session)
            )

        app.dependency_overrides[get_db_session] = override_get_db_session
        app.dependency_overrides[get_mobile_children_service] = _override_children_service
        cls.client = TestClient(app)

    @classmethod
    def tearDownClass(cls) -> None:
        app.dependency_overrides.clear()
        Base.metadata.drop_all(cls.engine)

    def setUp(self) -> None:
        with self.SessionLocal() as session:
            session.query(MobileSession).delete()
            session.query(MobileUser).delete()
            session.commit()

    def _authenticate(self, email: str = 'child_test@example.com') -> dict:
        resp = self.client.post(
            '/api/v1/mobile/auth/register',
            json={'email': email, 'password': 'Pass123456'},
        )
        self.assertEqual(resp.status_code, 200, resp.text)
        return resp.json()

    def _headers(self, auth: dict) -> dict:
        return {'Authorization': f"Bearer {auth['access_token']}"}

    # ─── List ──────────────────────────────────────────────────────────────────

    def test_list_children_empty_for_new_user(self) -> None:
        auth = self._authenticate()
        resp = self.client.get(
            '/api/v1/mobile/me/children',
            headers=self._headers(auth),
        )
        self.assertEqual(resp.status_code, 200)
        self.assertEqual(resp.json()['items'], [])

    def test_list_children_requires_auth(self) -> None:
        resp = self.client.get('/api/v1/mobile/me/children')
        self.assertEqual(resp.status_code, 401)

    # ─── Create ────────────────────────────────────────────────────────────────

    def test_create_child_returns_201(self) -> None:
        auth = self._authenticate()
        resp = self.client.post(
            '/api/v1/mobile/me/children',
            json={'name': 'Аяша', 'birthDate': '2020-06-15', 'gender': 'female'},
            headers=self._headers(auth),
        )
        self.assertEqual(resp.status_code, 201, resp.text)
        data = resp.json()
        self.assertEqual(data['name'], 'Аяша')
        self.assertEqual(data['birthDate'], '2020-06-15')
        self.assertEqual(data['gender'], 'female')
        self.assertIn('id', data)

    def test_created_child_appears_in_list(self) -> None:
        auth = self._authenticate()
        headers = self._headers(auth)
        self.client.post(
            '/api/v1/mobile/me/children',
            json={'name': 'Алибек', 'birthDate': '2019-03-10', 'gender': 'male'},
            headers=headers,
        )
        resp = self.client.get('/api/v1/mobile/me/children', headers=headers)
        items = resp.json()['items']
        self.assertEqual(len(items), 1)
        self.assertEqual(items[0]['name'], 'Алибек')

    def test_create_child_rejects_future_birth_date(self) -> None:
        auth = self._authenticate()
        future = date.today().replace(year=date.today().year + 1).isoformat()
        resp = self.client.post(
            '/api/v1/mobile/me/children',
            json={'name': 'Тест', 'birthDate': future, 'gender': 'male'},
            headers=self._headers(auth),
        )
        self.assertEqual(resp.status_code, 422)

    def test_create_child_rejects_empty_name(self) -> None:
        auth = self._authenticate()
        resp = self.client.post(
            '/api/v1/mobile/me/children',
            json={'name': '   ', 'birthDate': '2021-01-01', 'gender': 'male'},
            headers=self._headers(auth),
        )
        self.assertEqual(resp.status_code, 422)

    # ─── Update ────────────────────────────────────────────────────────────────

    def test_update_child_changes_name(self) -> None:
        auth = self._authenticate()
        headers = self._headers(auth)
        created = self.client.post(
            '/api/v1/mobile/me/children',
            json={'name': 'Старое', 'birthDate': '2021-05-05', 'gender': 'male'},
            headers=headers,
        ).json()
        child_id = created['id']

        resp = self.client.patch(
            f'/api/v1/mobile/me/children/{child_id}',
            json={'name': 'Новое'},
            headers=headers,
        )
        self.assertEqual(resp.status_code, 200)
        self.assertEqual(resp.json()['name'], 'Новое')
        # Other fields unchanged
        self.assertEqual(resp.json()['gender'], 'male')

    def test_update_child_not_found_for_another_user(self) -> None:
        auth1 = self._authenticate('user1_children@test.com')
        auth2 = self._authenticate('user2_children@test.com')

        created = self.client.post(
            '/api/v1/mobile/me/children',
            json={'name': 'Мой', 'birthDate': '2022-01-01', 'gender': 'female'},
            headers=self._headers(auth1),
        ).json()
        child_id = created['id']

        resp = self.client.patch(
            f'/api/v1/mobile/me/children/{child_id}',
            json={'name': 'Взломан'},
            headers=self._headers(auth2),
        )
        self.assertEqual(resp.status_code, 404)

    # ─── Delete ────────────────────────────────────────────────────────────────

    def test_delete_child_204_and_not_in_list(self) -> None:
        auth = self._authenticate()
        headers = self._headers(auth)
        created = self.client.post(
            '/api/v1/mobile/me/children',
            json={'name': 'Удалить', 'birthDate': '2020-01-01', 'gender': 'male'},
            headers=headers,
        ).json()
        child_id = created['id']

        resp = self.client.delete(
            f'/api/v1/mobile/me/children/{child_id}',
            headers=headers,
        )
        self.assertEqual(resp.status_code, 204)
        items = self.client.get(
            '/api/v1/mobile/me/children', headers=headers
        ).json()['items']
        self.assertEqual(items, [])

    def test_delete_nonexistent_child_404(self) -> None:
        auth = self._authenticate()
        resp = self.client.delete(
            '/api/v1/mobile/me/children/nonexistent-id',
            headers=self._headers(auth),
        )
        self.assertEqual(resp.status_code, 404)

    def test_children_are_scoped_per_user(self) -> None:
        auth1 = self._authenticate('user_a_children@test.com')
        auth2 = self._authenticate('user_b_children@test.com')

        # User A adds child
        self.client.post(
            '/api/v1/mobile/me/children',
            json={'name': 'Ребёнок А', 'birthDate': '2020-01-01', 'gender': 'male'},
            headers=self._headers(auth1),
        )

        # User B's list should be empty
        resp = self.client.get(
            '/api/v1/mobile/me/children',
            headers=self._headers(auth2),
        )
        self.assertEqual(resp.json()['items'], [])


if __name__ == '__main__':
    unittest.main()
