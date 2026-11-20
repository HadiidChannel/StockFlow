# Modul Pembelajaran 09: Docker Containerization & Multi-Service Orchestration

## 1. Konsep yang Digunakan
- Docker Images dan Containers.
- Multi-Stage Dockerfile Builds.
- Docker Compose Orchestration (`services`, `networks`, `volumes`).
- Healthchecks dan Container Dependencies (`depends_on: { condition: service_healthy }`).
- Persistent Volume Management untuk Database.

## 2. Mengapa Konsep Ini Diperlukan
Docker memastikan bahwa aplikasi berjalan secara identik di laptop pengembang, server CI/CD, maupun lingkungan production. Docker mengeliminasi masalah klasik "it works on my machine" akibat perbedaan versi Node.js atau MySQL di mesin lokal.

## 3. Cara Kerja
Docker menggunakan fitur kernel Linux (namespaces dan cgroups) untuk mengisolasi proses dalam kontainer yang ringan. Docker Compose mengorkestrasi jaringan virtual internal (`stockflow-network`) sehingga kontainer backend dapat mengakses database menggunakan hostname `db:3306` tanpa mengekspos port database ke jaringan publik.

## 4. Contoh Kode dalam Konteks StockFlow
```yaml
# Cuplikan docker-compose.yml
services:
  db:
    image: mysql:8.4
    restart: always
    environment:
      MYSQL_ROOT_PASSWORD: ${DB_ROOT_PASSWORD}
      MYSQL_DATABASE: stockflow_db
      MYSQL_USER: stockflow_user
      MYSQL_PASSWORD: ${DB_PASSWORD}
    volumes:
      - mysql_data:/var/lib/mysql
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
      interval: 10s
      timeout: 5s
      retries: 5

  backend:
    build:
      context: ./backend
      target: runner
    ports:
      - "4000:4000"
    environment:
      DATABASE_URL: mysql://stockflow_user:${DB_PASSWORD}@db:3306/stockflow_db
    depends_on:
      db:
        condition: service_healthy

volumes:
  mysql_data:
```

## 5. Penjelasan Bagian Penting Kode
1. `healthcheck`: Memastikan backend baru dijalankan setelah MySQL benar-benar siap menerima koneksi, mencegah error crash saat inisialisasi awal.
2. `mysql_data` volume: Data inventaris tetap tersimpan aman di disk host meskipun container dimatikan atau di-restart.

## 6. Kesalahan Umum yang Perlu Dihindari
- Menyimpan data database di dalam filesystem sementara container tanpa mendefinisikan persistent named volume.
- Mengirim folder `node_modules` host ke dalam konteks build Docker (selalu sertakan di `.dockerignore`).
