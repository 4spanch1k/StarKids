from __future__ import annotations

from base64 import b64decode, b64encode
from dataclasses import dataclass
import hashlib
import hmac
import re

from argon2 import PasswordHasher, Type
from argon2.exceptions import (
    InvalidHashError,
    VerificationError,
    VerifyMismatchError,
)

SCRYPT_N = 2**14
SCRYPT_R = 8
SCRYPT_P = 1
SCRYPT_DKLEN = 64
PASSWORD_HASH_PREFIX = 'scrypt'
ARGON2ID_PREFIX = '$argon2id$'

_PASSWORD_HASHER = PasswordHasher(
    time_cost=3,
    memory_cost=65536,
    parallelism=4,
    hash_len=32,
    salt_len=16,
    type=Type.ID,
)
_DUMMY_PASSWORD_HASH = _PASSWORD_HASHER.hash('StarKidsDummyPassword#2026')
_COMMON_WEAK_PASSWORDS = {
    '12345678',
    '123456789',
    '1234567890',
    '11111111',
    'qwerty123',
    'password',
    'password1',
    'password123',
    'letmein123',
    'admin12345',
}
_HAS_LETTER_RE = re.compile(r'[A-Za-z]')
_HAS_DIGIT_RE = re.compile(r'\d')
_HAS_SYMBOL_RE = re.compile(r'[^A-Za-z0-9]')


@dataclass(frozen=True)
class PasswordVerificationResult:
    is_valid: bool
    upgraded_hash: str | None = None


class PasswordPolicyError(ValueError):
    pass


def hash_password(password: str) -> str:
    return _PASSWORD_HASHER.hash(password)


def verify_password(password: str, password_hash: str) -> bool:
    return verify_and_upgrade_password(password, password_hash).is_valid


def verify_and_upgrade_password(
    password: str,
    password_hash: str,
) -> PasswordVerificationResult:
    if password_hash.startswith(ARGON2ID_PREFIX):
        try:
            _PASSWORD_HASHER.verify(password_hash, password)
        except (InvalidHashError, VerificationError, VerifyMismatchError):
            return PasswordVerificationResult(is_valid=False)

        upgraded_hash = None
        if _PASSWORD_HASHER.check_needs_rehash(password_hash):
            upgraded_hash = hash_password(password)
        return PasswordVerificationResult(
            is_valid=True,
            upgraded_hash=upgraded_hash,
        )

    if _verify_legacy_scrypt_password(password, password_hash):
        return PasswordVerificationResult(
            is_valid=True,
            upgraded_hash=hash_password(password),
        )

    return PasswordVerificationResult(is_valid=False)


def run_dummy_password_verification(password: str) -> None:
    try:
        _PASSWORD_HASHER.verify(_DUMMY_PASSWORD_HASH, password)
    except (InvalidHashError, VerificationError, VerifyMismatchError):
        return


def describe_password_hash(password_hash: str) -> str:
    if password_hash.startswith(ARGON2ID_PREFIX):
        return 'argon2id'
    if password_hash.startswith(f'{PASSWORD_HASH_PREFIX}$'):
        return 'scrypt'
    return 'unknown'


def validate_password_strength(password: str, *, min_length: int) -> None:
    normalized = password.strip().lower()
    if len(password) < min_length:
        raise PasswordPolicyError(
            f'Пароль должен содержать минимум {min_length} символов.'
        )
    if normalized in _COMMON_WEAK_PASSWORDS or 'password' in normalized:
        raise PasswordPolicyError(
            'Пароль слишком слабый. Используйте более сложную комбинацию.'
        )

    diversity = sum(
        (
            bool(_HAS_LETTER_RE.search(password)),
            bool(_HAS_DIGIT_RE.search(password)),
            bool(_HAS_SYMBOL_RE.search(password)),
        )
    )
    if diversity < 2:
        raise PasswordPolicyError(
            'Пароль слишком слабый. Добавьте буквы, цифры или символы.'
        )
    if len(set(password)) < 4:
        raise PasswordPolicyError(
            'Пароль слишком простой. Используйте более разнообразные символы.'
        )


def _verify_legacy_scrypt_password(password: str, password_hash: str) -> bool:
    try:
        algorithm, n_value, r_value, p_value, salt_segment, hash_segment = (
            password_hash.split('$')
        )
        if algorithm != PASSWORD_HASH_PREFIX:
            return False
        salt = b64decode(salt_segment.encode('ascii'))
        expected_hash = b64decode(hash_segment.encode('ascii'))
        calculated_hash = hashlib.scrypt(
            password=password.encode('utf-8'),
            salt=salt,
            n=int(n_value),
            r=int(r_value),
            p=int(p_value),
            dklen=len(expected_hash),
        )
    except (TypeError, ValueError):
        return False

    return hmac.compare_digest(calculated_hash, expected_hash)
