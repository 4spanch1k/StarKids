from __future__ import annotations

import unittest
from datetime import UTC, date, datetime, timedelta

from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from app.core.database.session import get_db_session
from app.db.models import Base
from app.db.models.mobile_child import MobileChild
from app.db.models.mobile_session import MobileSession
from app.db.models.mobile_user import MobileUser
from app.main import app


class MobileOnboardingEndpointTests(unittest.TestCase):
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

        app.dependency_overrides[get_db_session] = override_get_db_session
        cls.client = TestClient(app)

    @classmethod
    def tearDownClass(cls) -> None:
        app.dependency_overrides.clear()
        Base.metadata.drop_all(cls.engine)

    def setUp(self) -> None:
        with self.SessionLocal() as session:
            session.query(MobileSession).delete()
            session.query(MobileChild).delete()
            session.query(MobileUser).delete()
            session.commit()

    def _authenticate(self, email: str = 'onboarding@example.com') -> dict:
        response = self.client.post(
            '/api/v1/mobile/auth/register',
            json={'email': email, 'password': 'Pass123456'},
        )
        self.assertEqual(response.status_code, 200, response.text)
        return response.json()

    def _headers(self, auth: dict) -> dict:
        return {'Authorization': f"Bearer {auth['access_token']}"}

    def _complete(self, auth: dict, **overrides) -> TestClient:
        body = {
            'firstName': 'Айжан',
            'children': [
                {'name': 'Ая', 'birthDate': '2020-05-01', 'gender': 'unspecified'},
            ],
            'privacyConsentAccepted': True,
            'privacyConsentVersion': 'v1-pending-legal',
        }
        body.update(overrides)
        return self.client.post(
            '/api/v1/mobile/onboarding/complete',
            headers=self._headers(auth),
            json=body,
        )

    def test_new_user_profile_is_incomplete_until_completion(self) -> None:
        auth = self._authenticate()
        response = self.client.get('/api/v1/mobile/me', headers=self._headers(auth))
        self.assertEqual(response.status_code, 200)
        self.assertFalse(response.json()['onboardingCompleted'])

    def test_complete_zero_children_is_rejected(self) -> None:
        auth = self._authenticate()
        response = self._complete(auth, children=[])
        self.assertEqual(response.status_code, 422, response.text)
        profile = self.client.get(
            '/api/v1/mobile/me', headers=self._headers(auth)
        )
        self.assertEqual(profile.status_code, 200)
        self.assertFalse(profile.json()['onboardingCompleted'])

    def test_complete_multiple_children_and_retry_is_idempotent(self) -> None:
        auth = self._authenticate('multiple@example.com')
        children = [
            {'name': 'Алина', 'birthDate': '2020-09-15', 'gender': 'female'},
            {'name': 'Әли', 'birthDate': '2018-01-03', 'gender': 'unspecified'},
            {'name': 'Данияр', 'birthDate': '2016-05-20', 'gender': 'male'},
        ]
        first = self._complete(auth, children=children)
        self.assertEqual(first.status_code, 200, first.text)
        self.assertEqual(len(first.json()['children']), 3)

        retry = self._complete(
            auth,
            firstName='Другое имя',
            children=children,
        )
        self.assertEqual(retry.status_code, 200, retry.text)
        self.assertEqual(retry.json()['profile']['firstName'], 'Айжан')
        self.assertEqual(len(retry.json()['children']), 3)

        with self.SessionLocal() as session:
            self.assertEqual(session.query(MobileChild).count(), 3)

    def test_first_and_optional_last_name_are_persisted(self) -> None:
        auth = self._authenticate('names@example.com')
        response = self._complete(auth, lastName='Садыкова')
        self.assertEqual(response.status_code, 200, response.text)
        self.assertEqual(response.json()['profile']['firstName'], 'Айжан')
        self.assertEqual(response.json()['profile']['lastName'], 'Садыкова')

    def test_identical_children_in_initial_payload_are_not_collapsed(self) -> None:
        auth = self._authenticate('twins@example.com')
        children = [
            {'name': 'Али', 'birthDate': '2020-05-01', 'gender': 'male'},
            {'name': 'Али', 'birthDate': '2020-05-01', 'gender': 'male'},
        ]

        first = self._complete(auth, children=children)
        self.assertEqual(first.status_code, 200, first.text)
        self.assertEqual(len(first.json()['children']), 2)

        retry = self._complete(auth, children=children)
        self.assertEqual(retry.status_code, 200, retry.text)
        self.assertEqual(len(retry.json()['children']), 2)

        with self.SessionLocal() as session:
            self.assertEqual(session.query(MobileChild).count(), 2)

    def test_consent_is_required(self) -> None:
        auth = self._authenticate('consent@example.com')
        response = self._complete(auth, privacyConsentAccepted=False)
        self.assertEqual(response.status_code, 422)
        self.assertEqual(response.json()['error']['code'], 'consent_required')

    def test_future_birth_date_is_rejected(self) -> None:
        auth = self._authenticate('future@example.com')
        future = (date.today() + timedelta(days=1)).isoformat()
        response = self._complete(
            auth,
            children=[{'name': 'Будущий', 'birthDate': future, 'gender': 'unspecified'}],
        )
        self.assertEqual(response.status_code, 422)

    def test_unspecified_gender_is_accepted(self) -> None:
        auth = self._authenticate('gender@example.com')
        response = self._complete(
            auth,
            children=[
                {'name': 'Ая', 'birthDate': '2022-02-02', 'gender': 'unspecified'}
            ],
        )
        self.assertEqual(response.status_code, 200, response.text)
        self.assertEqual(response.json()['children'][0]['gender'], 'unspecified')

    def test_endpoint_requires_authentication(self) -> None:
        response = self.client.post(
            '/api/v1/mobile/onboarding/complete',
            json={
                'firstName': 'Айжан',
                'children': [
                    {'name': 'Ая', 'birthDate': '2020-05-01', 'gender': 'unspecified'},
                ],
                'privacyConsentAccepted': True,
                'privacyConsentVersion': 'v1-pending-legal',
            },
        )
        self.assertEqual(response.status_code, 401)

    def test_completed_existing_user_without_children_remains_valid(self) -> None:
        auth = self._authenticate('legacy-empty-family@example.com')
        with self.SessionLocal() as session:
            user = session.query(MobileUser).one()
            user.onboarding_completed_at = datetime.now(UTC)
            session.commit()

        response = self.client.get('/api/v1/mobile/me', headers=self._headers(auth))
        self.assertEqual(response.status_code, 200)
        self.assertTrue(response.json()['onboardingCompleted'])
        with self.SessionLocal() as session:
            self.assertEqual(session.query(MobileChild).count(), 0)
