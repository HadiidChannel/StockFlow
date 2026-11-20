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

// Request interceptor: menyertakan CSRF token secara otomatis pada mutasi
api.interceptors.request.use((config) => {
  const method = config.method?.toUpperCase();
  if (['POST', 'PUT', 'PATCH', 'DELETE'].includes(method || '')) {
    const csrfToken = getCsrfTokenFromCookie();
    if (csrfToken) {
      config.headers['X-CSRF-Token'] = csrfToken;
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
