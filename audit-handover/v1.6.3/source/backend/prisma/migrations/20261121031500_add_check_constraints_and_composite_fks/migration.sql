-- P1-01: Add 9 Business Invariant CHECK Constraints
ALTER TABLE `products` ADD CONSTRAINT `chk_products_minimum_stock` CHECK (`minimum_stock` >= 0);
ALTER TABLE `products` ADD CONSTRAINT `chk_products_cost_price` CHECK (`cost_price` IS NULL OR `cost_price` >= 0);
ALTER TABLE `inventory_balances` ADD CONSTRAINT `chk_inventory_balance_quantity` CHECK (`quantity` >= 0);
ALTER TABLE `stock_transaction_items` ADD CONSTRAINT `chk_items_quantity` CHECK (`quantity` > 0);
ALTER TABLE `stock_transaction_items` ADD CONSTRAINT `chk_items_balance_before` CHECK (`balance_before` >= 0);
ALTER TABLE `stock_transaction_items` ADD CONSTRAINT `chk_items_balance_after` CHECK (`balance_after` >= 0);
ALTER TABLE `stock_movements` ADD CONSTRAINT `chk_movements_quantity` CHECK (`quantity` > 0);
ALTER TABLE `stock_movements` ADD CONSTRAINT `chk_movements_balance_before` CHECK (`balance_before` >= 0);
ALTER TABLE `stock_movements` ADD CONSTRAINT `chk_movements_balance_after` CHECK (`balance_after` >= 0);

-- P1-02: Add Composite Foreign Keys for Stock Movement Integrity
ALTER TABLE `stock_movements` ADD CONSTRAINT `fk_movements_transaction_warehouse` 
    FOREIGN KEY (`transaction_id`, `warehouse_id`) 
    REFERENCES `stock_transactions`(`id`, `warehouse_id`) 
    ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE `stock_movements` ADD CONSTRAINT `fk_movements_transaction_item_product` 
    FOREIGN KEY (`transaction_id`, `transaction_item_id`, `product_id`) 
    REFERENCES `stock_transaction_items`(`transaction_id`, `id`, `product_id`) 
    ON DELETE RESTRICT ON UPDATE CASCADE;
