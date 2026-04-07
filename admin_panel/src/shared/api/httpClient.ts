import { env } from '@/shared/config/env';

type RequestOptions = RequestInit & {
  path: string;
};

export class HttpError extends Error {
  status: number;
  payload: unknown;

  constructor(message: string, status: number, payload: unknown) {
    super(message);
    this.name = 'HttpError';
    this.status = status;
    this.payload = payload;
  }
}

export async function httpClient<T>({ path, ...options }: RequestOptions): Promise<T> {
  const response = await fetch(`${env.apiBaseUrl}${path}`, {
    headers: {
      'Content-Type': 'application/json',
      ...options.headers,
    },
    ...options,
  });

  if (!response.ok) {
    const payload = await readResponseBody(response);
    throw new HttpError(resolveErrorMessage(response.status, payload), response.status, payload);
  }

  return (await readResponseBody(response)) as T;
}

async function readResponseBody(response: Response): Promise<unknown> {
  const contentType = response.headers.get('content-type') || '';
  if (contentType.includes('application/json')) {
    return response.json();
  }

  const text = await response.text();
  return text || null;
}

function resolveErrorMessage(status: number, payload: unknown): string {
  if (typeof payload === 'object' && payload !== null) {
    const typedPayload = payload as {
      error?: { message?: unknown };
      message?: unknown;
    };

    if (typeof typedPayload.error?.message === 'string') {
      return typedPayload.error.message;
    }
    if (typeof typedPayload.message === 'string') {
      return typedPayload.message;
    }
  }

  return `Request failed with status ${status}`;
}
