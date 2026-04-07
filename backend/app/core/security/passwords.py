from __future__ import annotations

from base64 import b64decode, b64encode
import hashlib
import hmac
import os

SCRYPT_N = 2**14
SCRYPT_R = 8
SCRYPT_P = 1
SCRYPT_DKLEN = 64
PASSWORD_HASH_PREFIX = 'scrypt'


def hash_password(password: str) -> str:
    salt = os.urandom(16)
    derived_key = hashlib.scrypt(
        password=password.encode('utf-8'),
        salt=salt,
        n=SCRYPT_N,
        r=SCRYPT_R,
        p=SCRYPT_P,
        dklen=SCRYPT_DKLEN,
    )
    salt_segment = b64encode(salt).decode('ascii')
    hash_segment = b64encode(derived_key).decode('ascii')
    return (
        f'{PASSWORD_HASH_PREFIX}${SCRYPT_N}${SCRYPT_R}${SCRYPT_P}'
        f'${salt_segment}${hash_segment}'
    )


def verify_password(password: str, password_hash: str) -> bool:
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
