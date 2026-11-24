const { PrismaClient } = require('../backend/node_modules/@prisma/client');
const prisma = new PrismaClient();

async function run() {
  try {
    const [ver] = await prisma.$queryRaw`SELECT VERSION() as version`;
    console.log('=== MYSQL VERSION ===');
    console.log(ver.version);

    console.log('\n=== 9 CHECK CONSTRAINTS IN INFORMATION_SCHEMA ===');
    const checks = await prisma.$queryRaw`
      SELECT CONSTRAINT_NAME, TABLE_NAME, CONSTRAINT_TYPE 
      FROM information_schema.TABLE_CONSTRAINTS 
      WHERE CONSTRAINT_SCHEMA = 'stockflow_db' AND CONSTRAINT_TYPE = 'CHECK'
      ORDER BY TABLE_NAME, CONSTRAINT_NAME
    `;
    console.table(checks);

    console.log('\n=== COMPOSITE FOREIGN KEYS IN INFORMATION_SCHEMA ===');
    const fks = await prisma.$queryRaw`
      SELECT CONSTRAINT_NAME, TABLE_NAME, COLUMN_NAME, ORDINAL_POSITION, REFERENCED_TABLE_NAME, REFERENCED_COLUMN_NAME 
      FROM information_schema.KEY_COLUMN_USAGE 
      WHERE CONSTRAINT_SCHEMA = 'stockflow_db' AND CONSTRAINT_NAME IN ('fk_movements_transaction_warehouse', 'fk_movements_transaction_item_product')
      ORDER BY CONSTRAINT_NAME, ORDINAL_POSITION
    `;
    console.table(fks);

    console.log('\n=== SHOW CREATE TABLE: inventory_balances ===');
    const [createBal] = await prisma.$queryRaw`SHOW CREATE TABLE inventory_balances`;
    console.log(createBal['Create Table'] || createBal['create table'] || Object.values(createBal)[1]);

    console.log('\n=== SHOW CREATE TABLE: stock_transactions ===');
    const [createTx] = await prisma.$queryRaw`SHOW CREATE TABLE stock_transactions`;
    console.log(createTx['Create Table'] || createTx['create table'] || Object.values(createTx)[1]);

    console.log('\n=== SHOW CREATE TABLE: stock_transaction_items ===');
    const [createItems] = await prisma.$queryRaw`SHOW CREATE TABLE stock_transaction_items`;
    console.log(createItems['Create Table'] || createItems['create table'] || Object.values(createItems)[1]);

    console.log('\n=== SHOW CREATE TABLE: stock_movements ===');
    const [createMov] = await prisma.$queryRaw`SHOW CREATE TABLE stock_movements`;
    console.log(createMov['Create Table'] || createMov['create table'] || Object.values(createMov)[1]);

    console.log('\n=== MIGRATIONS EXECUTED ===');
    const migs = await prisma.$queryRaw`
      SELECT migration_name, finished_at, rolled_back_at, checksum 
      FROM _prisma_migrations 
      ORDER BY finished_at ASC
    `;
    console.table(migs);

  } catch (err) {
    console.error('Error during verification:', err);
  } finally {
    await prisma.$disconnect();
  }
}

run();
