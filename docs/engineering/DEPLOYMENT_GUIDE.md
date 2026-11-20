# StockFlow Deployment & Operations Guide

## 1. Arsitektur Deployment
StockFlow didesain untuk dijalankan menggunakan Docker Compose dalam lingkungan kontainer terisolasi yang terdiri dari 3 service utama:
1. `frontend`: Next.js production build yang melayani aplikasi web pada port 3000.
2. `backend`: Node.js Express.js server yang melayani REST API pada port 4000.
3. `db`: MySQL 8.4 LTS dengan persistent volume pada storage engine InnoDB.

```text
[ Internet / Browser ]
          │
          ▼
    [ Reverse Proxy (Nginx / Cloudflare) ]
          │
          ├── /api/v1/* ──> [ backend:4000 ]
          │                        │
          │                        ▼
          │                 [ db:3306 (Internal) ]
          │
          └── /* ─────────> [ frontend:3000 ]
```

## 2. Environment Variables

### Backend Environment (.env)
```env
NODE_ENV=production
PORT=4000
DATABASE_URL="mysql://stockflow_user:secure_password@db:3306/stockflow_db"
FRONTEND_URL="http://localhost:3000"
COOKIE_DOMAIN=""
COOKIE_SECURE=true
COOKIE_SAME_SITE=lax
SESSION_SECRET="super-secure-random-secret-at-least-32-chars"
CSRF_SECRET="another-secure-random-secret-for-csrf"
LOG_LEVEL=info
```

### Frontend Environment (.env)
```env
NODE_ENV=production
PORT=3000
NEXT_PUBLIC_API_URL="http://localhost:4000/api/v1"
```

## 3. Langkah Menjalankan dengan Docker Compose

### Mode Development
```bash
docker compose -f docker-compose.dev.yml up --build
```

### Mode Production
```bash
# 1. Pastikan environment variables sudah diset di .env
cp .env.example .env

# 2. Build dan jalankan seluruh container di background
docker compose up -d --build

# 3. Jalankan migrasi database di container backend
docker compose exec backend npx prisma migrate deploy

# 4. Jalankan seeder role awal
docker compose exec backend npm run db:seed

# 5. Jalankan bootstrap Admin dan Organisasi awal
docker compose exec -it backend npm run db:bootstrap
```

## 4. Keamanan Container
1. User Non-Root: Image Docker backend dan frontend menggunakan non-root user (`node`).
2. Isolasi Database: Service MySQL tidak mengekspos port 3306 ke publik pada mode production (`expose` saja di Docker network internal).
3. Secret Sanitization: Tidak menaruh secret di dalam Dockerfile layer.
