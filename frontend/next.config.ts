import type { NextConfig } from 'next';

const nextConfig: NextConfig = {
  output: 'standalone',
  reactStrictMode: true,
  async rewrites() {
    const isProduction = process.env.NODE_ENV === 'production';
    const defaultBackendUrl = isProduction ? 'http://backend:4000' : 'http://localhost:4000';
    const backendUrl = process.env.INTERNAL_BACKEND_URL || defaultBackendUrl;
    return [
      {
        source: '/api/v1/:path*',
        destination: `${backendUrl}/api/v1/:path*`,
      },
    ];
  },
};

export default nextConfig;
