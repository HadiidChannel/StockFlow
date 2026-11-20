import { Prisma, TransactionType } from '@prisma/client';

export async function getNextSequenceNumber(
  tx: Prisma.TransactionClient,
  type: TransactionType
): Promise<string> {
  const now = new Date();
  const year = now.getUTCFullYear();
  const month = String(now.getUTCMonth() + 1).padStart(2, '0');
  const day = String(now.getUTCDate()).padStart(2, '0');
  const dateStr = `${year}${month}${day}`;

  // Use midnight UTC for periodDate
  const periodDate = new Date(Date.UTC(year, now.getUTCMonth(), now.getUTCDate()));

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
