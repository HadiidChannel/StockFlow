import type { Config } from 'tailwindcss';

const config: Config = {
  darkMode: ['class'],
  content: [
    './src/pages/**/*.{js,ts,jsx,tsx,mdx}',
    './src/components/**/*.{js,ts,jsx,tsx,mdx}',
    './src/app/**/*.{js,ts,jsx,tsx,mdx}',
  ],
  theme: {
    extend: {
      colors: {
        background: 'var(--sf-bg)',
        foreground: 'var(--sf-text-primary)',
        surface: {
          DEFAULT: 'var(--sf-surface)',
          subtle: 'var(--sf-surface-subtle)',
          hover: 'var(--sf-surface-hover)',
        },
        primary: {
          DEFAULT: 'var(--sf-primary)',
          hover: 'var(--sf-primary-hover)',
          soft: 'var(--sf-primary-soft)',
        },
        accent: {
          DEFAULT: 'var(--sf-accent)',
          strong: 'var(--sf-accent-strong)',
        },
        sf: {
          success: 'var(--sf-success)',
          warning: 'var(--sf-warning)',
          danger: 'var(--sf-danger)',
          info: 'var(--sf-info)',
          border: 'var(--sf-border)',
          'border-strong': 'var(--sf-border-strong)',
        },
      },
      fontFamily: {
        sans: ['var(--font-geist-sans)', 'Inter', 'system-ui', 'sans-serif'],
        mono: ['var(--font-geist-mono)', 'monospace'],
      },
      borderRadius: {
        sm: '6px',
        md: '10px',
        lg: '14px',
        xl: '20px',
        '2xl': '28px',
      },
    },
  },
  plugins: [require('tailwindcss-animate')],
};

export default config;
