-- StockFlow MySQL 8.4 schema baseline
-- Source: ERD_Database_Specification_StockFlow_v1.0.md
-- Engine: InnoDB | Charset: utf8mb4 | Timestamps: UTC
-- Review before production deployment.

SET NAMES utf8mb4;
SET time_zone = '+00:00';

CREATE TABLE organizations (
    id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    name VARCHAR(160) NOT NULL,
    code VARCHAR(40) NULL,
    address VARCHAR(500) NULL,
    phone VARCHAR(40) NULL,
    email VARCHAR(160) NULL,
    timezone VARCHAR(64) NOT NULL DEFAULT 'Asia/Makassar',
    currency CHAR(3) NOT NULL DEFAULT 'IDR',
    created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
    PRIMARY KEY (id),
    UNIQUE KEY uq_organizations_code (code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_ci;

CREATE TABLE roles (
    id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    code VARCHAR(40) NOT NULL,
    name VARCHAR(80) NOT NULL,
    created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    PRIMARY KEY (id),
    UNIQUE KEY uq_roles_code (code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_ci;

CREATE TABLE users (
    id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    organization_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    role_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    name VARCHAR(120) NOT NULL,
    email VARCHAR(160) COLLATE utf8mb4_0900_as_ci NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    status ENUM('ACTIVE', 'INACTIVE') NOT NULL DEFAULT 'ACTIVE',
    must_change_password BOOLEAN NOT NULL DEFAULT FALSE,
    theme_preference ENUM('LIGHT', 'DARK', 'SYSTEM') NOT NULL DEFAULT 'SYSTEM',
    last_login_at DATETIME(3) NULL,
    created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
    created_by CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NULL,
    updated_by CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_users_email (email),
    KEY idx_users_org_status (organization_id, status),
    KEY idx_users_role (role_id),
    CONSTRAINT fk_users_organization FOREIGN KEY (organization_id)
        REFERENCES organizations (id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_users_role FOREIGN KEY (role_id)
        REFERENCES roles (id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_users_created_by FOREIGN KEY (created_by)
        REFERENCES users (id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_users_updated_by FOREIGN KEY (updated_by)
        REFERENCES users (id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_ci;

CREATE TABLE sessions (
    id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    user_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    token_hash CHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    csrf_token_hash CHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    expires_at DATETIME(3) NOT NULL,
    revoked_at DATETIME(3) NULL,
    last_seen_at DATETIME(3) NULL,
    created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    PRIMARY KEY (id),
    UNIQUE KEY uq_sessions_token_hash (token_hash),
    KEY idx_sessions_user_expires (user_id, expires_at),
    CONSTRAINT fk_sessions_user FOREIGN KEY (user_id)
        REFERENCES users (id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_ci;

CREATE TABLE categories (
    id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    organization_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    name VARCHAR(100) NOT NULL,
    description VARCHAR(500) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
    created_by CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    updated_by CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_categories_org_name (organization_id, name),
    KEY idx_categories_org_active (organization_id, is_active),
    CONSTRAINT fk_categories_organization FOREIGN KEY (organization_id)
        REFERENCES organizations (id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_categories_created_by FOREIGN KEY (created_by)
        REFERENCES users (id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_categories_updated_by FOREIGN KEY (updated_by)
        REFERENCES users (id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_ci;

CREATE TABLE products (
    id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    organization_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    category_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    name VARCHAR(160) NOT NULL,
    sku VARCHAR(64) NOT NULL,
    unit VARCHAR(24) NOT NULL,
    minimum_stock DECIMAL(18,3) NOT NULL DEFAULT 0.000,
    cost_price DECIMAL(18,2) NULL,
    description VARCHAR(1000) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
    created_by CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    updated_by CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_products_org_sku (organization_id, sku),
    KEY idx_products_org_name (organization_id, name),
    KEY idx_products_category_active (category_id, is_active),
    CONSTRAINT chk_products_minimum_stock CHECK (minimum_stock >= 0),
    CONSTRAINT chk_products_cost_price CHECK (cost_price IS NULL OR cost_price >= 0),
    CONSTRAINT fk_products_organization FOREIGN KEY (organization_id)
        REFERENCES organizations (id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_products_category FOREIGN KEY (category_id)
        REFERENCES categories (id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_products_created_by FOREIGN KEY (created_by)
        REFERENCES users (id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_products_updated_by FOREIGN KEY (updated_by)
        REFERENCES users (id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_ci;

CREATE TABLE warehouses (
    id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    organization_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    name VARCHAR(160) NOT NULL,
    code VARCHAR(32) NOT NULL,
    location VARCHAR(255) NULL,
    description VARCHAR(500) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
    created_by CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    updated_by CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_warehouses_org_code (organization_id, code),
    KEY idx_warehouses_org_active (organization_id, is_active),
    CONSTRAINT fk_warehouses_organization FOREIGN KEY (organization_id)
        REFERENCES organizations (id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_warehouses_created_by FOREIGN KEY (created_by)
        REFERENCES users (id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_warehouses_updated_by FOREIGN KEY (updated_by)
        REFERENCES users (id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_ci;

CREATE TABLE user_warehouse_assignments (
    user_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    warehouse_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    assigned_by CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    PRIMARY KEY (user_id, warehouse_id),
    KEY idx_uwa_warehouse_user (warehouse_id, user_id),
    CONSTRAINT fk_uwa_user FOREIGN KEY (user_id)
        REFERENCES users (id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_uwa_warehouse FOREIGN KEY (warehouse_id)
        REFERENCES warehouses (id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_uwa_assigned_by FOREIGN KEY (assigned_by)
        REFERENCES users (id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_ci;

CREATE TABLE inventory_balances (
    id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    product_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    warehouse_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    quantity DECIMAL(18,3) NOT NULL DEFAULT 0.000,
    created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
    PRIMARY KEY (id),
    UNIQUE KEY uq_balance_product_warehouse (product_id, warehouse_id),
    KEY idx_balance_warehouse_product (warehouse_id, product_id),
    CONSTRAINT chk_inventory_balance_quantity CHECK (quantity >= 0),
    CONSTRAINT fk_balance_product FOREIGN KEY (product_id)
        REFERENCES products (id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_balance_warehouse FOREIGN KEY (warehouse_id)
        REFERENCES warehouses (id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_ci;

CREATE TABLE stock_transactions (
    id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    organization_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    warehouse_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    created_by CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    created_by_name_snapshot VARCHAR(120) NOT NULL,
    type ENUM('IN', 'OUT') NOT NULL,
    reference_number VARCHAR(40) NOT NULL,
    status ENUM('POSTED') NOT NULL DEFAULT 'POSTED',
    note VARCHAR(1000) NULL,
    external_reference VARCHAR(120) NULL,
    correction_of_transaction_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NULL,
    warehouse_name_snapshot VARCHAR(160) NOT NULL,
    warehouse_code_snapshot VARCHAR(32) NOT NULL,
    posted_at DATETIME(3) NOT NULL,
    created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    PRIMARY KEY (id),
    UNIQUE KEY uq_transactions_reference (reference_number),
    UNIQUE KEY uq_transactions_correction_of (correction_of_transaction_id),
    UNIQUE KEY uq_transactions_id_warehouse (id, warehouse_id),
    KEY idx_transactions_posted (posted_at),
    KEY idx_transactions_type_posted (type, posted_at),
    KEY idx_transactions_warehouse_posted (warehouse_id, posted_at),
    CONSTRAINT fk_transactions_organization FOREIGN KEY (organization_id)
        REFERENCES organizations (id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_transactions_warehouse FOREIGN KEY (warehouse_id)
        REFERENCES warehouses (id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_transactions_created_by FOREIGN KEY (created_by)
        REFERENCES users (id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_transactions_correction_of FOREIGN KEY (correction_of_transaction_id)
        REFERENCES stock_transactions (id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_ci;

CREATE TABLE stock_transaction_items (
    id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    transaction_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    product_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    product_name_snapshot VARCHAR(160) NOT NULL,
    sku_snapshot VARCHAR(64) NOT NULL,
    unit_snapshot VARCHAR(24) NOT NULL,
    quantity DECIMAL(18,3) NOT NULL,
    balance_before DECIMAL(18,3) NOT NULL,
    balance_after DECIMAL(18,3) NOT NULL,
    created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    PRIMARY KEY (id),
    UNIQUE KEY uq_items_transaction_product (transaction_id, product_id),
    UNIQUE KEY uq_items_tx_id_product (transaction_id, id, product_id),
    KEY idx_items_product_transaction (product_id, transaction_id),
    CONSTRAINT chk_items_quantity CHECK (quantity > 0),
    CONSTRAINT chk_items_balance_before CHECK (balance_before >= 0),
    CONSTRAINT chk_items_balance_after CHECK (balance_after >= 0),
    CONSTRAINT fk_items_transaction FOREIGN KEY (transaction_id)
        REFERENCES stock_transactions (id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_items_product FOREIGN KEY (product_id)
        REFERENCES products (id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_ci;

CREATE TABLE stock_movements (
    id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    transaction_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    transaction_item_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    product_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    warehouse_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    type ENUM('IN', 'OUT') NOT NULL,
    quantity DECIMAL(18,3) NOT NULL,
    balance_before DECIMAL(18,3) NOT NULL,
    balance_after DECIMAL(18,3) NOT NULL,
    created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    PRIMARY KEY (id),
    UNIQUE KEY uq_movements_transaction_item (transaction_item_id),
    KEY idx_movements_product_created (product_id, created_at),
    KEY idx_movements_warehouse_created (warehouse_id, created_at),
    KEY idx_movements_type_created (type, created_at),
    CONSTRAINT chk_movements_quantity CHECK (quantity > 0),
    CONSTRAINT chk_movements_balance_before CHECK (balance_before >= 0),
    CONSTRAINT chk_movements_balance_after CHECK (balance_after >= 0),
    CONSTRAINT fk_movements_transaction_warehouse FOREIGN KEY (transaction_id, warehouse_id)
        REFERENCES stock_transactions (id, warehouse_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_movements_transaction_item_product FOREIGN KEY (transaction_id, transaction_item_id, product_id)
        REFERENCES stock_transaction_items (transaction_id, id, product_id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_ci;

CREATE TABLE stock_transaction_sequences (
    id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    transaction_type ENUM('IN', 'OUT') NOT NULL,
    period_date DATE NOT NULL,
    last_number INT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    UNIQUE KEY uq_transaction_sequence_type_date (transaction_type, period_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_ci;

CREATE TABLE idempotency_records (
    id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    user_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    idempotency_key VARCHAR(128) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    request_hash CHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    transaction_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NULL,
    response_status SMALLINT UNSIGNED NULL,
    response_body JSON NULL,
    created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    expires_at DATETIME(3) NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_idempotency_user_key (user_id, idempotency_key),
    KEY idx_idempotency_expires (expires_at),
    KEY idx_idempotency_transaction (transaction_id),
    CONSTRAINT fk_idempotency_user FOREIGN KEY (user_id)
        REFERENCES users (id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_idempotency_transaction FOREIGN KEY (transaction_id)
        REFERENCES stock_transactions (id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_ci;

-- Seed role awal. Gunakan UUID tetap agar seed dapat diulang dengan aman.
INSERT INTO roles (id, code, name)
VALUES
    ('00000000-0000-4000-8000-000000000001', 'ADMIN', 'Administrator'),
    ('00000000-0000-4000-8000-000000000002', 'WAREHOUSE_STAFF', 'Warehouse Staff')
AS incoming_role
ON DUPLICATE KEY UPDATE name = incoming_role.name;

-- Bootstrap organizations + first Admin must be executed by a protected CLI command,
-- inside one database transaction. Do not place the initial password in this file.
