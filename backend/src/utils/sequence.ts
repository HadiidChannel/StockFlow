import { Prisma, TransactionType } from '@prisma/client';

export function getLocalCalendarDate(
  date: Date = new Date(),
  timeZone = 'Asia/Makassar'
): {
  dateStr: string;
  year: number;
  month: number;
  day: number;
} {
  try {
    const formatter = new Intl.DateTimeFormat('en-CA', {
      timeZone,
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
    });
    // 'en-CA' yields 'YYYY-MM-DD'
    const parts = formatter.format(date).split('-');
    const year = parseInt(parts[0], 10);
    const month = parseInt(parts[1], 10);
    const day = parseInt(parts[2], 10);
    const dateStr = `${parts[0]}${parts[1]}${parts[2]}`;
    return { dateStr, year, month, day };
  } catch {
    // Fallback if timezone string is invalid
    const year = date.getUTCFullYear();
    const month = date.getUTCMonth() + 1;
    const day = date.getUTCDate();
    const dateStr = `${year}${String(month).padStart(2, '0')}${String(day).padStart(2, '0')}`;
    return { dateStr, year, month, day };
  }
}

export async function getNextSequenceNumber(
  tx: Prisma.TransactionClient,
  type: TransactionType,
  timeZone: string = 'Asia/Makassar'
): Promise<string> {
  const { dateStr, year, month, day } = getLocalCalendarDate(new Date(), timeZone);

  // Midnight UTC representing this specific local calendar day
  const periodDate = new Date(Date.UTC(year, month - 1, day));

  // Upsert sequence row atomically with increment
  const sequence = await tx.stockTransactionSequence.upsert({
    where: {
      transactionType_periodDate: {
        transactionType: type,
        periodDate,
      },
    },
    create: {
      transactionType: type,
      periodDate,
      lastNumber: 1,
    },
    update: {
      lastNumber: {
        increment: 1,
      },
    },
  });

  const paddedNumber = String(sequence.lastNumber).padStart(6, '0');
  return `${type}-${dateStr}-${paddedNumber}`;
}
