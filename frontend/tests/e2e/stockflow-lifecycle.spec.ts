import { test, expect } from '@playwright/test';

test.describe('StockFlow Full Lifecycle End-to-End Testing (Real Database & API)', () => {
  const timestamp = Date.now();
  const categoryName = `Kategori E2E ${timestamp}`;
  const productSku = `SKU-E2E-${timestamp}`;
  const productName = `Sensor Presisi ${timestamp}`;
  const warehouseAssignedName = `Gudang Utama JKT ${timestamp}`;
  const warehouseAssignedCode = `W1${timestamp.toString().slice(-4)}`;
  const warehouseUnassignedName = `Gudang Terlarang SUB ${timestamp}`;
  const warehouseUnassignedCode = `W2${timestamp.toString().slice(-4)}`;
  const staffEmail = `staff.${timestamp}@stockflow.com`;
  const staffName = `Staf Operasional ${timestamp}`;
  const staffPassword = 'StaffPassword2026!';

  let createdProductId = '';
  let unassignedWarehouseId = '';

  test('Complete 13-stage inventory lifecycle workflow', async ({ page, context }) => {
    // -------------------------------------------------------------------------
    // Stage 1: Admin Login
    // -------------------------------------------------------------------------
    console.log('[E2E Stage 1] Admin Login');
    await page.goto('/login');
    await expect(page).toHaveTitle(/StockFlow/i);
    await page.fill('input[type="email"]', 'admin@stockflow.com');
    await page.fill('input[type="password"]', 'AdminStockFlow2026!');
    await page.click('button[type="submit"]');

    // Verify redirect to dashboard and admin role
    await expect(page).toHaveURL(/.*dashboard/);
    await expect(page.locator('header')).toContainText('Administrator');

    // -------------------------------------------------------------------------
    // Stage 2: Membuat Produk dan Kategori
    // -------------------------------------------------------------------------
    console.log('[E2E Stage 2] Create Category and Product');
    // 2a. Create Category
    await page.goto('/categories');
    await page.click('button:has-text("Tambah Kategori Baru")');
    await page.fill('input[placeholder="Contoh: Perangkat Jaringan"]', categoryName);
    await page.fill('input[placeholder*="Router, Switch"]', 'Kategori pengujian otomatis Playwright E2E');
    await page.click('button:has-text("Simpan Kategori")');
    await expect(page.locator('table')).toContainText(categoryName);

    // 2b. Create Product
    await page.goto('/products');
    await page.click('button:has-text("Tambah Produk Baru")');
    await page.fill('input[placeholder="Contoh: Kabel UTP Cat6 305m"]', productName);
    await page.fill('input[placeholder="Contoh: KBL-UTP-C6"]', productSku);
    await page.selectOption('div[class*="fixed"] select', { label: categoryName });
    await page.fill('input[placeholder="PCS, BOX, ROLL, KG"]', 'PCS');
    await page.fill('input[placeholder="5.000"]', '5.000');
    await page.click('button:has-text("Simpan Produk")');
    await expect(page.locator('table')).toContainText(productSku);
    await expect(page.locator('table')).toContainText(productName);

    // Capture created product ID via Admin session
    const prodRes = await page.request.get(`/api/v1/products?search=${productSku}`);
    const prodData = await prodRes.json();
    createdProductId = prodData.data[0].id;
    console.log('Created Product UUID:', createdProductId);

    // -------------------------------------------------------------------------
    // Stage 3: Membuat Gudang (1 Ditugaskan, 1 Tidak Ditugaskan)
    // -------------------------------------------------------------------------
    console.log('[E2E Stage 3] Create Warehouses');
    await page.goto('/warehouses');
    
    // 3a. Assigned Warehouse
    await page.click('button:has-text("Tambah Gudang Baru")');
    await page.fill('input[placeholder="Contoh: Gudang Sentral Jakarta"]', warehouseAssignedName);
    await page.fill('input[placeholder="Contoh: WH_JKT_01"]', warehouseAssignedCode);
    await page.fill('input[placeholder*="Pulogadung"]', 'Jakarta Barat - Hub Distribusi');
    await page.click('button:has-text("Simpan Gudang")');
    await expect(page.locator(`text=${warehouseAssignedName}`)).toBeVisible();

    // 3b. Unassigned Warehouse (for testing RBAC restriction)
    await page.click('button:has-text("Tambah Gudang Baru")');
    await page.fill('input[placeholder="Contoh: Gudang Sentral Jakarta"]', warehouseUnassignedName);
    await page.fill('input[placeholder="Contoh: WH_JKT_01"]', warehouseUnassignedCode);
    await page.fill('input[placeholder*="Pulogadung"]', 'Surabaya Timur - Regional Hub');
    await page.click('button:has-text("Simpan Gudang")');
    await expect(page.locator(`text=${warehouseUnassignedName}`)).toBeVisible();

    // Capture unassigned warehouse ID via Admin session
    const whRes = await page.request.get('/api/v1/warehouses');
    const whData = await whRes.json();
    const foundUnassigned = whData.data.find((w: any) => w.code === warehouseUnassignedCode);
    unassignedWarehouseId = foundUnassigned.id;
    console.log('Unassigned Warehouse UUID for RBAC Test:', unassignedWarehouseId);

    // -------------------------------------------------------------------------
    // Stage 4: Melakukan Stock In
    // -------------------------------------------------------------------------
    console.log('[E2E Stage 4] Stock In 50 Units');
    await page.goto('/inventory/stock-in');
    
    // Wait for warehouse options to load and select
    const whOption = page.locator(`option:has-text("${warehouseAssignedCode}")`);
    await whOption.waitFor({ state: 'attached', timeout: 15000 });
    const whVal = await whOption.getAttribute('value');
    console.log('Stock In - Warehouse UUID:', whVal);
    await page.locator('select').first().selectOption(whVal!);

    // Wait for product options to load and select
    const prodOption = page.locator(`option:has-text("${productSku}")`);
    await prodOption.waitFor({ state: 'attached', timeout: 15000 });
    const prodVal = await prodOption.getAttribute('value');
    console.log('Stock In - Product UUID:', prodVal);
    await page.locator('select').nth(1).selectOption(prodVal!);

    // Fill Quantity 50.000
    const qtyInput = page.locator('input.font-mono.text-right').first();
    await qtyInput.fill('50.000');
    await page.fill('input[placeholder*="SJ-2026"]', `PO-${timestamp}`);
    await page.fill('input[placeholder*="kondisi barang"]', 'Penerimaan batch awal Playwright E2E');
    
    await page.click('button:has-text("Posting Stock In")');
    await expect(page.locator('text=Stock In Berhasil Diposting!')).toBeVisible();

    // -------------------------------------------------------------------------
    // Stage 5: Memeriksa Saldo Aktual
    // -------------------------------------------------------------------------
    console.log('[E2E Stage 5] Verify Inventory Balance');
    await page.goto('/inventory');
    await page.fill('input[placeholder*="Cari produk"]', productSku);
    const balanceRow = page.locator('tbody tr', { hasText: productSku });
    await expect(balanceRow).toBeVisible();
    await expect(balanceRow).toContainText('50');
    await expect(balanceRow).toContainText(warehouseAssignedName);

    // -------------------------------------------------------------------------
    // Stage 6: Membuat Warehouse Staff
    // -------------------------------------------------------------------------
    console.log('[E2E Stage 6] Create Warehouse Staff');
    await page.goto('/users');
    await page.click('button:has-text("Tambah Pengguna")');
    await page.fill('input[placeholder="Contoh: Budi Prasetyo"]', staffName);
    await page.fill('input[placeholder="budi@stockflow.com"]', staffEmail);
    await page.fill('input[placeholder*="Minimal 8 karakter"]', staffPassword);
    await page.selectOption('div[class*="fixed"] select', { value: 'WAREHOUSE_STAFF' });
    
    // Check only the assigned warehouse in the add user modal
    const assignedCheckbox = page.locator(`div[class*="fixed"] label:has-text("${warehouseAssignedName}") input[type="checkbox"]`);
    await assignedCheckbox.scrollIntoViewIfNeeded();
    await assignedCheckbox.check({ force: true });

    await page.click('button:has-text("Simpan Akun")');
    await expect(page.locator('table')).toContainText(staffEmail);
    await expect(page.locator('table')).toContainText(staffName);

    // -------------------------------------------------------------------------
    // Stage 7: Melakukan Warehouse Assignment
    // -------------------------------------------------------------------------
    console.log('[E2E Stage 7] Verify and Manage Warehouse Assignment');
    const staffRow = page.locator('tbody tr', { hasText: staffEmail });
    await expect(staffRow).toContainText(warehouseAssignedName);
    
    // Open warehouse assignment dialog to verify and confirm
    await staffRow.locator('button:has-text("Gudang")').click();
    await expect(page.locator('h3:has-text("Penugasan Gudang")')).toBeVisible();
    const modalAssignedBox = page.locator(`div[class*="fixed"] label:has-text("${warehouseAssignedName}") input[type="checkbox"]`);
    await expect(modalAssignedBox).toBeChecked();
    
    const modalUnassignedBox = page.locator(`div[class*="fixed"] label:has-text("${warehouseUnassignedName}") input[type="checkbox"]`);
    await expect(modalUnassignedBox).not.toBeChecked();

    await page.click('button:has-text("Simpan Penugasan")');
    await expect(page.locator('h3:has-text("Penugasan Gudang")')).not.toBeVisible();

    // -------------------------------------------------------------------------
    // Stage 8: Warehouse Staff Login
    // -------------------------------------------------------------------------
    console.log('[E2E Stage 8] Staff Logout and Login (with Forced Password Change)');
    await page.click('button[aria-label="Logout"]');
    await expect(page).toHaveURL(/.*login/);

    await page.fill('input[type="email"]', staffEmail);
    await page.fill('input[type="password"]', staffPassword);
    await page.click('button[type="submit"]');

    // Security guard: new users must change password on first login
    await expect(page).toHaveURL(/.*change-password/);
    console.log('[E2E Stage 8] Forced password change security guard verified');
    const newStaffPassword = 'StaffPermanentPassword2026!';
    await page.locator('input[type="password"]').first().fill(staffPassword);
    await page.locator('input[type="password"]').nth(1).fill(newStaffPassword);
    await page.locator('input[type="password"]').nth(2).fill(newStaffPassword);
    await page.click('button[type="submit"]');

    await expect(page).toHaveURL(/.*dashboard/);
    await expect(page.locator('header')).toContainText(staffName);
    await expect(page.locator('header')).toContainText('Warehouse Staff');

    // -------------------------------------------------------------------------
    // Stage 9: Melakukan Stock Out
    // -------------------------------------------------------------------------
    console.log('[E2E Stage 9] Stock Out 15 Units');
    await page.goto('/inventory/stock-out');
    
    // Select Assigned Warehouse by option value
    const soWhOption = page.locator(`option:has-text("${warehouseAssignedCode}")`);
    await soWhOption.waitFor({ state: 'attached', timeout: 15000 });
    const soWhVal = await soWhOption.getAttribute('value');
    await page.locator('select').first().selectOption(soWhVal!);

    // Select Product by option value
    const soProdOption = page.locator(`option:has-text("${productSku}")`);
    await soProdOption.waitFor({ state: 'attached', timeout: 15000 });
    const soProdVal = await soProdOption.getAttribute('value');
    await page.locator('select').nth(1).selectOption(soProdVal!);

    // Verify live balance indicator shows balance panel
    await expect(page.locator('text=Saldo Tersedia di Gudang Ini')).toBeVisible();

    // Fill Quantity 15.000
    await page.fill('input.font-mono', '15.000');
    await page.fill('input[placeholder*="DO-2026"]', `DO-${timestamp}`);
    await page.fill('input[placeholder*="Keterangan pengiriman"]', 'Pengeluaran pesanan operasional staff');

    await page.click('button:has-text("Posting Stock Out")');
    await expect(page.locator('text=Stock Out Berhasil Diposting!')).toBeVisible();

    // -------------------------------------------------------------------------
    // Stage 10: Memeriksa Stock Movement History
    // -------------------------------------------------------------------------
    console.log('[E2E Stage 10] Verify Movement Ledger');
    await page.goto('/movements');
    await page.fill('input[placeholder*="Cari referensi"]', productSku);
    
    const movementsTable = page.locator('table');
    await expect(movementsTable).toContainText('MASUK');
    await expect(movementsTable).toContainText('+50');
    await expect(movementsTable).toContainText('KELUAR');
    await expect(movementsTable).toContainText('-15');
    await expect(movementsTable).toContainText('35');

    // -------------------------------------------------------------------------
    // Stage 11 & 12: Mencoba Mengakses Gudang yang Tidak Ditugaskan & Memastikan Ditolak
    // -------------------------------------------------------------------------
    console.log('[E2E Stage 11 & 12] Access Unassigned Warehouse -> 403 Forbidden');
    
    // Extract CSRF token from page cookie
    const cookies = await context.cookies();
    const csrfCookie = cookies.find((c) => c.name === 'sf_csrf');
    const csrfToken = csrfCookie ? csrfCookie.value : '';

    const forbiddenRes = await page.request.post('/api/v1/inventory/stock-out', {
      headers: {
        'x-csrf-token': csrfToken,
        'Idempotency-Key': `e2e-forbidden-${Date.now()}`,
      },
      data: {
        warehouseId: unassignedWarehouseId,
        items: [
          {
            productId: createdProductId,
            quantity: '5.000',
          },
        ],
        note: 'Percobaan akses gudang terlarang',
      },
    });

    // Stage 12: Ensure Access is strictly Forbidden (HTTP 403)
    expect(forbiddenRes.status()).toBe(403);
    const forbiddenBody = await forbiddenRes.json();
    console.log('Forbidden response payload:', forbiddenBody);
    expect(forbiddenBody.error.message).toContain('Akses ditolak');

    // -------------------------------------------------------------------------
    // Stage 13: Melakukan Full Reversal dan Memeriksa Saldo Akhir
    // -------------------------------------------------------------------------
    console.log('[E2E Stage 13] Full Reversal and Final Balance Check');
    await page.goto('/movements');
    await page.fill('input[placeholder*="Cari referensi"]', productSku);

    // Click Reversal button on the OUT transaction row
    const outRow = page.locator('tbody tr', { hasText: 'KELUAR' }).first();
    await outRow.locator('button:has-text("Reversal")').click();

    // Reversal confirmation modal
    await expect(page.locator('h3:has-text("Konfirmasi Reversal Transaksi")')).toBeVisible();
    await page.fill('input[placeholder*="Contoh: Kesalahan input"]', 'Pembatalan transaksi salah kirim E2E');
    await page.click('button:has-text("Lakukan Pembalikan Penuh")');

    // Expect success message
    await expect(page.locator('text=Transaksi berhasil dibatalkan')).toBeVisible();

    // Verify final inventory balance is restored back to 50 PCS
    await page.goto('/inventory');
    await page.fill('input[placeholder*="Cari produk"]', productSku);
    const finalRow = page.locator('tbody tr', { hasText: productSku });
    await expect(finalRow).toBeVisible();
    await expect(finalRow).toContainText('50');
    console.log('[E2E Stage 13] Saldo akhir berhasil dikembalikan ke 50 PCS setelah Full Reversal');
  });
});
