import * as React from 'react';
import { cva, type VariantProps } from 'class-variance-authority';
import { cn } from '@/lib/utils';

const badgeVariants = cva(
  'inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-semibold transition-colors focus:outline-none focus:ring-2 focus:ring-ring focus:ring-offset-2',
  {
    variants: {
      variant: {
        default:
          'border-transparent bg-[var(--sf-primary)] text-white shadow hover:opacity-80',
        secondary:
          'border-transparent bg-[var(--sf-surface-subtle)] text-[var(--sf-text-primary)] hover:bg-[var(--sf-surface-hover)]',
        success:
          'border-transparent bg-[#2F8966]/15 text-[#2F8966] dark:bg-[#69C69B]/20 dark:text-[#69C69B]',
        warning:
          'border-transparent bg-[#B87925]/15 text-[#B87925] dark:bg-[#E5B566]/20 dark:text-[#E5B566]',
        danger:
          'border-transparent bg-[#C65360]/15 text-[#C65360] dark:bg-[#E27B85]/20 dark:text-[#E27B85]',
        outline: 'border border-[var(--sf-border)] text-[var(--sf-text-primary)]',
      },
    },
    defaultVariants: {
      variant: 'default',
    },
  }
);

export interface BadgeProps
  extends React.HTMLAttributes<HTMLDivElement>,
    VariantProps<typeof badgeVariants> {}

function Badge({ className, variant, ...props }: BadgeProps) {
  return (
    <div className={cn(badgeVariants({ variant }), className)} {...props} />
  );
}

export { Badge, badgeVariants };
