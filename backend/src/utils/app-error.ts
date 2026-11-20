export interface ErrorDetail {
  field?: string;
  message: string;
}

export class AppError extends Error {
  public readonly statusCode: number;
  public readonly code: string;
  public readonly details?: ErrorDetail[];
  public readonly isOperational: boolean;

  constructor(
    message: string,
    statusCode = 400,
    code = 'BAD_REQUEST',
    details?: ErrorDetail[]
  ) {
    super(message);
    this.statusCode = statusCode;
    this.code = code;
    this.details = details;
    this.isOperational = true;

    Object.setPrototypeOf(this, new.target.prototype);
    Error.captureStackTrace(this, this.constructor);
  }
}

export class NotFoundError extends AppError {
  constructor(message = 'Resource tidak ditemukan.', code = 'NOT_FOUND', details?: ErrorDetail[]) {
    super(message, 404, code, details);
  }
}

export class UnauthorizedError extends AppError {
  constructor(message = 'Autentikasi diperlukan.', code = 'UNAUTHORIZED', details?: ErrorDetail[]) {
    super(message, 401, code, details);
  }
}

export class ForbiddenError extends AppError {
  constructor(message = 'Akses ditolak.', code = 'FORBIDDEN', details?: ErrorDetail[]) {
    super(message, 403, code, details);
  }
}

export class ValidationError extends AppError {
  constructor(message = 'Validasi gagal.', details?: ErrorDetail[]) {
    super(message, 400, 'VALIDATION_ERROR', details);
  }
}

export class ConflictError extends AppError {
  constructor(message = 'Terjadi konflik data.', code = 'CONFLICT', details?: ErrorDetail[]) {
    super(message, 409, code, details);
  }
}

export class InsufficientStockError extends AppError {
  constructor(message = 'Stok tersedia tidak mencukupi.', details?: ErrorDetail[]) {
    super(message, 422, 'INSUFFICIENT_STOCK', details);
  }
}
