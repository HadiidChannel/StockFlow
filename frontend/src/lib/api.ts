import axios, { AxiosError } from 'axios';

const API_BASE_URL = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:4000/api/v1';

export const api = axios.create({
  baseURL: API_BASE_URL,
  withCredentials: true,
  headers: {
    'Content-Type': 'application/json',
  },
});

// Helper untuk membaca CSRF token dari cookie browser
export function getCsrfTokenFromCookie(): string | null {
  if (typeof document === 'undefined') return null;
  const match = document.cookie.match(new RegExp('(^|;\\s*)sf_csrf=([^;]*)'));
  return match ? decodeURIComponent(match[2]) : null;
}

// Helper untuk menghasilkan Idempotency-Key UUID v4
export function generateIdempotencyKey(): string {
  if (typeof crypto !== 'undefined' && crypto.randomUUID) {
    return crypto.randomUUID();
  }
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (c) => {
    const r = (Math.random() * 16) | 0;
    const v = c === 'x' ? r : (r & 0x3) | 0x8;
    return v.toString(16);
  });
}

// Request interceptor: menyertakan CSRF token dan Idempotency-Key secara otomatis pada mutasi
api.interceptors.request.use((config) => {
  const method = config.method?.toUpperCase();
  if (['POST', 'PUT', 'PATCH', 'DELETE'].includes(method || '')) {
    const csrfToken = getCsrfTokenFromCookie();
    if (csrfToken) {
      config.headers['X-CSRF-Token'] = csrfToken;
    }

    // Attach Idempotency-Key for mutative inventory endpoints if not already provided
    const url = config.url || '';
    if (
      !config.headers['Idempotency-Key'] &&
      (url.includes('/inventory/stock-in') ||
        url.includes('/inventory/stock-out') ||
        (url.includes('/inventory/transactions') && url.includes('/reversal')))
    ) {
      config.headers['Idempotency-Key'] = generateIdempotencyKey();
    }
  }
  return config;
});

export interface ApiErrorResponse {
  error: {
    code: string;
    message: string;
    details?: Array<{ field?: string; message: string }>;
    requestId: string;
  };
}

export function getErrorMessage(err: unknown): string {
  if (axios.isAxiosError(err)) {
    const axiosError = err as AxiosError<ApiErrorResponse>;
    if (axiosError.response?.data?.error?.message) {
      return axiosError.response.data.error.message;
    }
  }
  if (err instanceof Error) {
    return err.message;
  }
  return 'Terjadi kesalahan pada sistem.';
}
