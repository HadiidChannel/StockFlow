import * as React from 'react';
import { Slot } from '@radix-ui/react-slot';
import { cva, type VariantProps } from 'class-variance-authority';
import { cn } from '@/lib/utils';

const buttonVariants = cva(
  'inline-flex items-center justify-center whitespace-nowrap rounded-md text-sm font-medium transition-colors focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-[var(--sf-primary)] disabled:pointer-events-none disabled:opacity-50',
  {
    variants: {
      variant: {
        default:
          'bg-[var(--sf-primary)] text-white shadow hover:bg-[var(--sf-primary-hover)]',
        destructive:
          'bg-[var(--sf-danger)] text-white shadow-sm hover:opacity-90',
        outline:
          'border border-[var(--sf-border)] bg-transparent shadow-sm hover:bg-[var(--sf-surface-subtle)] hover:text-[var(--sf-text-primary)]',
        secondary:
          'bg-[var(--sf-surface-subtle)] text-[var(--sf-text-primary)] shadow-sm hover:bg-[var(--sf-surface-hover)]',
        ghost: 'hover:bg-[var(--sf-surface-subtle)] hover:text-[var(--sf-text-primary)]',
        link: 'text-[var(--sf-primary)] underline-offset-4 hover:underline',
        glow: 'relative overflow-hidden bg-gradient-to-t from-[#9ad9ec] via-[#0596b3] to-[#0a111d] text-white shadow-lg hover:brightness-110 transition-all font-semibold',
      },
      size: {
        default: 'h-9 px-4 py-2',
        sm: 'h-8 rounded-md px-3 text-xs',
        lg: 'h-11 rounded-md px-8 text-base',
        icon: 'h-9 w-9',
      },
    },
    defaultVariants: {
      variant: 'default',
      size: 'default',
    },
  }
);

export interface ButtonProps
  extends React.ButtonHTMLAttributes<HTMLButtonElement>,
    VariantProps<typeof buttonVariants> {
  asChild?: boolean;
}

const Button = React.forwardRef<HTMLButtonElement, ButtonProps>(
  ({ className, variant, size, asChild = false, ...props }, ref) => {
    const Comp = asChild ? Slot : 'button';
    return (
      <Comp
        className={cn(buttonVariants({ variant, size, className }))}
        ref={ref}
        {...props}
      />
    );
  }
);
Button.displayName = 'Button';

export { Button, buttonVariants };
