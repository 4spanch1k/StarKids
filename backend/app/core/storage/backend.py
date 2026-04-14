from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path
from typing import TYPE_CHECKING, Protocol, runtime_checkable

if TYPE_CHECKING:
    from ..config.settings import Settings


@dataclass(frozen=True)
class StoredFile:
    url: str
    storage_key: str


@runtime_checkable
class StorageBackend(Protocol):
    def save(
        self,
        content: bytes,
        storage_key: str,
        content_type: str,
    ) -> StoredFile: ...

    def delete(self, storage_key: str) -> None: ...


class LocalStorageBackend:
    def __init__(self, *, media_root: str, public_base_url: str | None, media_url_prefix: str) -> None:
        self._media_root = Path(media_root)
        self._public_base_url = (public_base_url or '').rstrip('/')
        self._media_url_prefix = media_url_prefix.rstrip('/')

    def save(self, content: bytes, storage_key: str, content_type: str) -> StoredFile:
        dest = self._media_root / storage_key
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_bytes(content)
        url = f'{self._public_base_url}{self._media_url_prefix}/{storage_key}'
        return StoredFile(url=url, storage_key=storage_key)

    def delete(self, storage_key: str) -> None:
        dest = self._media_root / storage_key
        try:
            dest.unlink(missing_ok=True)
        except OSError:
            pass


class S3StorageBackend:
    def __init__(
        self,
        *,
        bucket: str,
        region: str | None = None,
        endpoint_url: str | None = None,
        access_key: str | None = None,
        secret_key: str | None = None,
        public_base_url: str | None = None,
    ) -> None:
        self._bucket = bucket
        self._region = region
        self._endpoint_url = endpoint_url
        self._access_key = access_key
        self._secret_key = secret_key
        self._public_base_url = (public_base_url or '').rstrip('/')
        self._client = None

    def _get_client(self):
        if self._client is None:
            import boto3  # type: ignore[import]

            kwargs: dict = {'service_name': 's3'}
            if self._region:
                kwargs['region_name'] = self._region
            if self._endpoint_url:
                kwargs['endpoint_url'] = self._endpoint_url
            if self._access_key and self._secret_key:
                kwargs['aws_access_key_id'] = self._access_key
                kwargs['aws_secret_access_key'] = self._secret_key
            self._client = boto3.client(**kwargs)
        return self._client

    def save(self, content: bytes, storage_key: str, content_type: str) -> StoredFile:
        client = self._get_client()
        client.put_object(
            Bucket=self._bucket,
            Key=storage_key,
            Body=content,
            ContentType=content_type,
        )
        if self._public_base_url:
            url = f'{self._public_base_url}/{storage_key}'
        else:
            url = f'https://{self._bucket}.s3.amazonaws.com/{storage_key}'
        return StoredFile(url=url, storage_key=storage_key)

    def delete(self, storage_key: str) -> None:
        client = self._get_client()
        try:
            client.delete_object(Bucket=self._bucket, Key=storage_key)
        except Exception:
            pass


def get_storage_backend(settings: 'Settings') -> StorageBackend:
    backend = settings.storage_backend.lower()
    if backend == 's3':
        return S3StorageBackend(
            bucket=settings.s3_bucket or '',
            region=settings.s3_region,
            endpoint_url=settings.s3_endpoint,
            access_key=settings.s3_access_key,
            secret_key=settings.s3_secret_key,
            public_base_url=settings.s3_public_base_url,
        )
    return LocalStorageBackend(
        media_root=settings.media_root,
        public_base_url=settings.public_base_url,
        media_url_prefix=settings.normalized_media_url_prefix,
    )
