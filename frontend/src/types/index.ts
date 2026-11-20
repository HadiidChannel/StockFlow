// Frontend Domain Models matching StockFlow API v1.0

export type RoleCode = 'ADMIN' | 'WAREHOUSE_STAFF';

export interface Role {
  code: RoleCode;
  name: string;
}

export interface User {
  id: string;
  name: string;
  email: string;
  role: Role;
  status: 'ACTIVE' | 'INACTIVE';
  mustChangePassword: boolean;
  themePreference: 'LIGHT' | 'DARK' | 'SYSTEM';
  lastLoginAt?: string | null;
  createdAt: string;
  assignedWarehouses?: Warehouse[];
}

export interface Organization {
  id: string;
  name: string;
  code?: string | null;
  address?: string | null;
  phone?: string | null;
  email?: string | null;
  timezone: string;
  currency: string;
}

export interface Warehouse {
  id: string;
  name: string;
  code: string;
  location?: string | null;
  description?: string | null;
  isActive: boolean;
  createdAt: string;
}

export interface Category {
  id: string;
  name: string;
  description?: string | null;
  isActive: boolean;
  createdAt: string;
}

export interface Product {
  id: string;
  name: string;
  sku: string;
  unit: string;
  minimumStock: string;
  costPrice?: string | null;
  description?: string | null;
  isActive: boolean;
  category: Category;
  categoryName?: string;
  totalQuantity?: string;
}

export interface InventoryBalance {
  id: string;
  productId: string;
  warehouseId: string;
  quantity: string;
  product: Product;
  warehouse: Warehouse;
  updatedAt: string;
}

export type TransactionType = 'IN' | 'OUT';

export interface StockTransactionItem {
  id: string;
  productId: string;
  productNameSnapshot: string;
  skuSnapshot: string;
  unitSnapshot: string;
  quantity: string;
  balanceBefore: string;
  balanceAfter: string;
}

export interface StockTransaction {
  id: string;
  referenceNumber: string;
  type: TransactionType;
  status: 'POSTED';
  warehouseId: string;
  warehouseNameSnapshot: string;
  warehouseCodeSnapshot: string;
  createdByNameSnapshot: string;
  note?: string | null;
  externalReference?: string | null;
  correctionOfTransactionId?: string | null;
  postedAt: string;
  items?: StockTransactionItem[];
}

export interface StockMovement {
  id: string;
  transactionId: string;
  transactionItemId?: string;
  referenceNumber?: string;
  createdByName?: string;
  productId: string;
  productName?: string;
  sku?: string;
  unit?: string;
  warehouseId: string;
  warehouseName?: string;
  warehouseCode?: string;
  type: TransactionType;
  quantity: string;
  balanceBefore: string;
  balanceAfter: string;
  note?: string | null;
  createdAt: string;
  product?: Product;
  warehouse?: Warehouse;
  transaction?: StockTransaction;
}

export interface DashboardSummary {
  totalProducts: number;
  totalWarehouses: number;
  lowStockCount: number;
  outOfStockCount: number;
  recentStockInCount: number;
  recentStockOutCount: number;
}
