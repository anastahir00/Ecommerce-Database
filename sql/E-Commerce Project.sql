/* ============================================================
   E-COMMERCE ORDER MANAGEMENT SYSTEM
   Database: SQL Server
   Author: Muhammad Anas Tahir
   Date: June 12, 2026
   ============================================================ */

-- ============================================================
-- PART 1: CLEANUP (Run this first if tables already exist)
-- ============================================================

-- Drop triggers first (to avoid dependency issues)
DROP TRIGGER IF EXISTS trg_decrement_inventory;
DROP TRIGGER IF EXISTS trg_audit_order_status;
DROP TRIGGER IF EXISTS trg_single_default_address;

-- Drop tables in reverse order (child before parent)
DROP TABLE IF EXISTS order_status_log;
DROP TABLE IF EXISTS payments;
DROP TABLE IF EXISTS order_items;
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS inventory;
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS categories;
DROP TABLE IF EXISTS addresses;
DROP TABLE IF EXISTS customers;

-- ============================================================
-- PART 2: CREATE TABLES (in dependency order)
-- ============================================================

PRINT 'Creating tables...';

-- 1. Customers table
CREATE TABLE customers (
    customer_id INT PRIMARY KEY IDENTITY(1,1),
    first_name NVARCHAR(50) NOT NULL,
    last_name NVARCHAR(50) NOT NULL,
    email NVARCHAR(100) NOT NULL UNIQUE,
    phone NVARCHAR(20),
    created_at DATETIME2 DEFAULT GETDATE()
);

-- 2. Addresses table
CREATE TABLE addresses (
    address_id    INT PRIMARY KEY IDENTITY(1,1),
    customer_id   INT           NOT NULL,
    street        NVARCHAR(150) NOT NULL,
    city          NVARCHAR(80)  NOT NULL,
    state         NVARCHAR(50),
    country       NVARCHAR(60)  NOT NULL,
    postal_code   NVARCHAR(20)  NOT NULL,
    is_default    BIT           DEFAULT 0,
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id) ON DELETE CASCADE
);

-- 3. Categories table (self-referencing for hierarchy)
CREATE TABLE categories (
    category_id        INT PRIMARY KEY IDENTITY(1,1),
    name               NVARCHAR(100) NOT NULL,
    parent_category_id INT           NULL,
    FOREIGN KEY (parent_category_id) REFERENCES categories(category_id)
);

-- 4. Products table
CREATE TABLE products (
    product_id    INT PRIMARY KEY IDENTITY(1,1),
    category_id   INT             NOT NULL,
    name          NVARCHAR(150)   NOT NULL,
    description   NVARCHAR(MAX),
    price         DECIMAL(10,2)   NOT NULL CHECK (price >= 0),
    weight_kg     DECIMAL(6,3),
    sku           NVARCHAR(50)    UNIQUE,
    is_active     BIT             DEFAULT 1,
    created_at    DATETIME2       DEFAULT GETDATE(),
    FOREIGN KEY (category_id) REFERENCES categories(category_id)
);

-- 5. Inventory table
CREATE TABLE inventory (
    inventory_id       INT PRIMARY KEY IDENTITY(1,1),
    product_id         INT NOT NULL UNIQUE,
    quantity_in_stock  INT NOT NULL DEFAULT 0 CHECK (quantity_in_stock >= 0),
    reorder_threshold  INT NOT NULL DEFAULT 10,
    last_updated       DATETIME2 DEFAULT GETDATE(),
    FOREIGN KEY (product_id) REFERENCES products(product_id) ON DELETE CASCADE
);

-- 6. Orders table
CREATE TABLE orders (
    order_id            INT PRIMARY KEY IDENTITY(1,1),
    customer_id         INT           NOT NULL,
    shipping_address_id INT           NOT NULL,
    subtotal            DECIMAL(10,2) NOT NULL CHECK (subtotal >= 0),
    discount            DECIMAL(10,2) DEFAULT 0.00 CHECK (discount >= 0),
    tax                 DECIMAL(10,2) DEFAULT 0.00 CHECK (tax >= 0),
    total_amount        DECIMAL(10,2) NOT NULL CHECK (total_amount >= 0),
    status              NVARCHAR(30)  NOT NULL DEFAULT 'pending',
    ordered_at          DATETIME2     DEFAULT GETDATE(),
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id),
    FOREIGN KEY (shipping_address_id) REFERENCES addresses(address_id)
);

-- 7. Order Items table (with computed column)
CREATE TABLE order_items (
    item_id      INT PRIMARY KEY IDENTITY(1,1),
    order_id     INT           NOT NULL,
    product_id   INT           NOT NULL,
    quantity     INT           NOT NULL CHECK (quantity > 0),
    unit_price   DECIMAL(10,2) NOT NULL CHECK (unit_price >= 0),
    line_total   AS (quantity * unit_price) PERSISTED,
    FOREIGN KEY (order_id) REFERENCES orders(order_id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES products(product_id)
);

-- 8. Payments table
CREATE TABLE payments (
    payment_id  INT PRIMARY KEY IDENTITY(1,1),
    order_id    INT           NOT NULL,
    amount      DECIMAL(10,2) NOT NULL CHECK (amount >= 0),
    method      NVARCHAR(30)  NOT NULL,
    status      NVARCHAR(20)  NOT NULL DEFAULT 'pending',
    paid_at     DATETIME2     DEFAULT GETDATE(),
    FOREIGN KEY (order_id) REFERENCES orders(order_id)
);

-- 9. Order Status Log table (for audit trail)
CREATE TABLE order_status_log (
    log_id      INT PRIMARY KEY IDENTITY(1,1),
    order_id    INT          NOT NULL,
    old_status  NVARCHAR(30),
    new_status  NVARCHAR(30) NOT NULL,
    changed_at  DATETIME2    DEFAULT GETDATE(),
    changed_by  NVARCHAR(100) DEFAULT SYSTEM_USER,
    FOREIGN KEY (order_id) REFERENCES orders(order_id) ON DELETE CASCADE
);

PRINT 'All tables created successfully.';

-- ============================================================
-- PART 3: CREATE INDEXES (for performance)
-- ============================================================

PRINT 'Creating indexes...';

-- Customers indexes
CREATE INDEX idx_customers_email ON customers(email);
CREATE INDEX idx_customers_created ON customers(created_at);

-- Addresses indexes
CREATE INDEX idx_addresses_customer ON addresses(customer_id);
CREATE INDEX idx_addresses_default ON addresses(customer_id, is_default);

-- Products indexes
CREATE INDEX idx_products_category ON products(category_id);
CREATE INDEX idx_products_price ON products(price);
CREATE INDEX idx_products_active ON products(is_active);

-- Inventory indexes
CREATE INDEX idx_inventory_stock ON inventory(quantity_in_stock, reorder_threshold);

-- Orders indexes
CREATE INDEX idx_orders_customer ON orders(customer_id);
CREATE INDEX idx_orders_status ON orders(status);
CREATE INDEX idx_orders_ordered_at ON orders(ordered_at);
CREATE INDEX idx_orders_customer_status ON orders(customer_id, status);

-- Order items indexes
CREATE INDEX idx_order_items_order ON order_items(order_id);
CREATE INDEX idx_order_items_product ON order_items(product_id);

-- Payments indexes
CREATE INDEX idx_payments_order ON payments(order_id);
CREATE INDEX idx_payments_status ON payments(status);

-- Status log indexes
CREATE INDEX idx_status_log_order ON order_status_log(order_id);
CREATE INDEX idx_status_log_changed_at ON order_status_log(changed_at);

PRINT 'All indexes created successfully.';

-- ============================================================
-- PART 4: CREATE TRIGGERS
-- ============================================================

PRINT 'Creating triggers...';

-- TRIGGER 1: Decrement inventory when order is placed
GO
CREATE TRIGGER trg_decrement_inventory
ON order_items
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Decrement stock
    UPDATE i
    SET i.quantity_in_stock = i.quantity_in_stock - inserted.quantity,
        i.last_updated = GETDATE()
    FROM inventory i
    INNER JOIN inserted ON i.product_id = inserted.product_id
    WHERE i.quantity_in_stock >= inserted.quantity;
    
    -- Check for products below reorder threshold
    IF EXISTS (
        SELECT 1 
        FROM inventory i
        INNER JOIN inserted ON i.product_id = inserted.product_id
        WHERE i.quantity_in_stock < i.reorder_threshold
    )
    BEGIN
        DECLARE @warning NVARCHAR(500);
        SET @warning = 'Warning: One or more products are below reorder threshold.';
        PRINT @warning;
    END
END;
GO

-- TRIGGER 2: Audit order status changes
GO
CREATE TRIGGER trg_audit_order_status
ON orders
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    
    IF UPDATE(status)
    BEGIN
        INSERT INTO order_status_log (order_id, old_status, new_status, changed_at)
        SELECT 
            i.order_id,
            d.status,
            i.status,
            GETDATE()
        FROM inserted i
        INNER JOIN deleted d ON i.order_id = d.order_id
        WHERE i.status != d.status;
    END
END;
GO

-- TRIGGER 3: Ensure only one default address per customer
GO
CREATE TRIGGER trg_single_default_address
ON addresses
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    
    IF UPDATE(is_default)
    BEGIN
        UPDATE a
        SET is_default = 0
        FROM addresses a
        INNER JOIN inserted i ON a.customer_id = i.customer_id
        WHERE i.is_default = 1 
          AND a.address_id != i.address_id
          AND a.is_default = 1;
    END
END;
GO

PRINT 'All triggers created successfully.';

-- ============================================================
-- PART 5: INSERT SAMPLE DATA
-- ============================================================

PRINT 'Inserting sample data...';

-- Insert Customers (10 customers)
INSERT INTO customers (first_name, last_name, email, phone) VALUES
('John', 'Smith', 'john.smith@email.com', '555-0101'),
('Emma', 'Johnson', 'emma.j@email.com', '555-0102'),
('Michael', 'Williams', 'michael.w@email.com', '555-0103'),
('Sophia', 'Brown', 'sophia.b@email.com', '555-0104'),
('James', 'Jones', 'james.j@email.com', '555-0105'),
('Olivia', 'Garcia', 'olivia.g@email.com', '555-0106'),
('William', 'Miller', 'william.m@email.com', '555-0107'),
('Ava', 'Davis', 'ava.d@email.com', '555-0108'),
('Benjamin', 'Rodriguez', 'ben.r@email.com', '555-0109'),
('Isabella', 'Martinez', 'isabella.m@email.com', '555-0110');

-- Insert Addresses
INSERT INTO addresses (customer_id, street, city, state, country, postal_code, is_default) VALUES
(1, '123 Main St', 'New York', 'NY', 'USA', '10001', 1),
(1, '456 Park Ave', 'Brooklyn', 'NY', 'USA', '11201', 0),
(2, '789 Oak Rd', 'Los Angeles', 'CA', 'USA', '90001', 1),
(3, '321 Pine Ln', 'Chicago', 'IL', 'USA', '60601', 1),
(4, '654 Elm St', 'Houston', 'TX', 'USA', '77001', 1),
(5, '987 Maple Dr', 'Phoenix', 'AZ', 'USA', '85001', 1),
(6, '147 Cedar Ave', 'Philadelphia', 'PA', 'USA', '19101', 1),
(7, '258 Birch Blvd', 'San Antonio', 'TX', 'USA', '78201', 1),
(8, '369 Walnut Way', 'San Diego', 'CA', 'USA', '92101', 1),
(9, '741 Spruce St', 'Dallas', 'TX', 'USA', '75201', 1),
(10, '852 Ash Ct', 'San Jose', 'CA', 'USA', '95101', 1);

-- Insert Categories (with hierarchy)
INSERT INTO categories (name, parent_category_id) VALUES
-- Level 1 categories
('Electronics', NULL),
('Clothing', NULL),
('Books', NULL),
('Home & Garden', NULL),
('Sports', NULL),

-- Level 2 categories (Electronics subcategories)
('Laptops', 1),
('Smartphones', 1),
('Tablets', 1),
('Headphones', 1),

-- Level 2 categories (Clothing subcategories)
('Men''s Clothing', 2),
('Women''s Clothing', 2),
('Kids'' Clothing', 2),

-- Level 3 categories (sub-subcategories)
('Gaming Laptops', 5),
('Ultrabooks', 5),
('Android Phones', 6),
('iPhone', 6),
('Wireless Headphones', 8);

-- Insert Products (20 products) - FIXED CATEGORY IDs
INSERT INTO products (category_id, name, description, price, weight_kg, sku, is_active) VALUES
-- Electronics - Laptops (category_id 6 = Laptops)
(6, 'Gaming Pro X', 'High-performance gaming laptop with RGB keyboard', 1499.99, 2.5, 'LAP-GPX-001', 1),
(6, 'Ultra Slim Book', 'Lightweight ultrabook for professionals', 1099.99, 1.2, 'LAP-USB-002', 1),
(6, 'Budget Laptop', 'Affordable laptop for daily tasks', 599.99, 1.8, 'LAP-BUD-003', 1),

-- Electronics - Smartphones (category_id 7 = Smartphones)
(7, 'Galaxy S25', 'Latest Android flagship', 999.99, 0.2, 'PHN-GAL-001', 1),
(7, 'Pixel 9 Pro', 'Pure Android experience', 899.99, 0.21, 'PHN-PIX-002', 1),

-- Electronics - iPhone (category_id 16 = iPhone)
(16, 'iPhone 16 Pro', 'Apple flagship with A18 chip', 1199.99, 0.22, 'PHN-IP16-003', 1),
(16, 'iPhone 16', 'Standard iPhone model', 999.99, 0.21, 'PHN-IP16-004', 1),

-- Electronics - Headphones (category_id 9 = Headphones)
(9, 'Noise Cancelling Pro', 'Premium ANC headphones', 299.99, 0.3, 'HP-PRO-001', 1),
(17, 'Sports Wireless Earbuds', 'Sweat-resistant earbuds', 89.99, 0.05, 'HP-SPT-002', 1),

-- Clothing - Men's (category_id 10 = Men's Clothing)
(10, 'Men''s Cotton T-Shirt', '100% cotton, regular fit', 24.99, 0.2, 'CLM-TSH-001', 1),
(10, 'Men''s Denim Jeans', 'Classic blue jeans', 59.99, 0.6, 'CLM-JEAN-002', 1),
(10, 'Men''s Winter Jacket', 'Water-resistant puffer jacket', 129.99, 1.1, 'CLM-JKT-003', 1),

-- Clothing - Women's (category_id 11 = Women's Clothing)
(11, 'Women''s Yoga Pants', 'Stretchy comfortable leggings', 39.99, 0.3, 'CLW-YOGA-001', 1),
(11, 'Women''s Blouse', 'Silk blend work blouse', 49.99, 0.25, 'CLW-BLOUSE-002', 1),

-- Books (category_id 3 = Books)
(3, 'SQL Mastery', 'Complete guide to SQL databases', 49.99, 0.8, 'BK-SQL-001', 1),
(3, 'Data Science Handbook', 'Machine learning and analytics', 69.99, 1.0, 'BK-DS-002', 1),

-- Home & Garden (category_id 4 = Home & Garden)
(4, 'Coffee Maker Deluxe', 'Programmable coffee machine', 89.99, 2.8, 'HG-COFF-001', 1),
(4, 'Garden Tool Set', '10-piece gardening kit', 49.99, 3.2, 'HG-GARD-002', 1),

-- Sports (category_id 5 = Sports)
(5, 'Yoga Mat Premium', 'Non-slip exercise mat', 29.99, 0.9, 'SP-YOGA-001', 1),
(5, 'Dumbbell Set 20kg', 'Adjustable dumbbells', 79.99, 20.0, 'SP-DUMB-002', 1);

-- Insert Inventory (one record per product)
INSERT INTO inventory (product_id, quantity_in_stock, reorder_threshold) VALUES
(1, 25, 10),
(2, 15, 8),
(3, 50, 20),
(4, 30, 12),
(5, 20, 10),
(6, 45, 15),
(7, 35, 15),
(8, 60, 20),
(9, 100, 30),
(10, 200, 50),
(11, 75, 25),
(12, 40, 15),
(13, 150, 40),
(14, 80, 25),
(15, 25, 10),
(16, 30, 12),
(17, 20, 8),
(18, 50, 20),
(19, 120, 35),
(20, 45, 15);

-- Insert Orders (15 orders)
INSERT INTO orders (customer_id, shipping_address_id, subtotal, discount, tax, total_amount, status, ordered_at) VALUES
(1, 1, 1499.99, 0, 120.00, 1619.99, 'delivered', DATEADD(day, -30, GETDATE())),
(1, 1, 89.99, 5.00, 6.80, 91.79, 'delivered', DATEADD(day, -20, GETDATE())),
(2, 3, 1199.99, 50.00, 92.00, 1241.99, 'shipped', DATEADD(day, -15, GETDATE())),
(2, 3, 49.99, 0, 4.00, 53.99, 'delivered', DATEADD(day, -45, GETDATE())),
(3, 4, 999.99, 0, 80.00, 1079.99, 'delivered', DATEADD(day, -60, GETDATE())),
(3, 4, 129.99, 10.00, 9.60, 129.59, 'shipped', DATEADD(day, -10, GETDATE())),
(4, 5, 599.99, 0, 48.00, 647.99, 'processing', DATEADD(day, -3, GETDATE())),
(5, 6, 299.99, 0, 24.00, 323.99, 'delivered', DATEADD(day, -25, GETDATE())),
(5, 6, 39.99, 0, 3.20, 43.19, 'shipped', DATEADD(day, -12, GETDATE())),
(6, 7, 79.99, 0, 6.40, 86.39, 'pending', DATEADD(day, -1, GETDATE())),
(7, 8, 49.99, 0, 4.00, 53.99, 'processing', DATEADD(day, -5, GETDATE())),
(8, 9, 69.99, 0, 5.60, 75.59, 'shipped', DATEADD(day, -8, GETDATE())),
(9, 10, 24.99, 0, 2.00, 26.99, 'delivered', DATEADD(day, -35, GETDATE())),
(9, 10, 89.99, 5.00, 6.80, 91.79, 'cancelled', DATEADD(day, -18, GETDATE())),
(10, 11, 1099.99, 100.00, 80.00, 1079.99, 'delivered', DATEADD(day, -40, GETDATE()));

-- Insert Order Items
INSERT INTO order_items (order_id, product_id, quantity, unit_price) VALUES
-- Order 1
(1, 1, 1, 1499.99),
-- Order 2
(2, 9, 1, 89.99),
-- Order 3
(3, 6, 1, 1199.99),
-- Order 4
(4, 14, 1, 49.99),
-- Order 5
(5, 5, 1, 999.99),
-- Order 6
(6, 12, 1, 129.99),
-- Order 7
(7, 3, 1, 599.99),
-- Order 8
(8, 8, 1, 299.99),
-- Order 9
(9, 13, 1, 39.99),
-- Order 10
(10, 18, 1, 79.99),
-- Order 11
(11, 15, 1, 49.99),
-- Order 12
(12, 16, 1, 69.99),
-- Order 13
(13, 10, 1, 24.99),
-- Order 14
(14, 9, 1, 89.99),
-- Order 15
(15, 2, 1, 1099.99);

-- Insert Payments
INSERT INTO payments (order_id, amount, method, status, paid_at) VALUES
(1, 1619.99, 'credit_card', 'completed', DATEADD(day, -29, GETDATE())),
(2, 91.79, 'paypal', 'completed', DATEADD(day, -19, GETDATE())),
(3, 1241.99, 'credit_card', 'completed', DATEADD(day, -14, GETDATE())),
(4, 53.99, 'debit_card', 'completed', DATEADD(day, -44, GETDATE())),
(5, 1079.99, 'credit_card', 'completed', DATEADD(day, -59, GETDATE())),
(6, 129.59, 'paypal', 'pending', NULL),
(7, 647.99, 'credit_card', 'pending', NULL),
(8, 323.99, 'debit_card', 'completed', DATEADD(day, -24, GETDATE())),
(9, 43.19, 'credit_card', 'completed', DATEADD(day, -11, GETDATE())),
(10, 86.39, 'paypal', 'pending', NULL),
(11, 53.99, 'credit_card', 'pending', NULL),
(12, 75.59, 'debit_card', 'completed', DATEADD(day, -7, GETDATE())),
(13, 26.99, 'credit_card', 'completed', DATEADD(day, -34, GETDATE())),
(14, 91.79, 'paypal', 'failed', NULL),
(15, 1079.99, 'credit_card', 'completed', DATEADD(day, -39, GETDATE()));

PRINT 'Sample data inserted successfully.';

-- ============================================================
-- PART 6: ANALYTICAL QUERIES (Business Intelligence)
-- ============================================================

PRINT 'Running analytical queries...';
PRINT '========================================';
PRINT '';

-- QUERY 1: Monthly Revenue Report
PRINT 'QUERY 1: Monthly Revenue Report';
PRINT '--------------------------------';
SELECT 
    YEAR(ordered_at) AS Year,
    MONTH(ordered_at) AS Month,
    DATENAME(month, ordered_at) AS MonthName,
    COUNT(DISTINCT o.order_id) AS TotalOrders,
    COUNT(DISTINCT o.customer_id) AS UniqueCustomers,
    SUM(o.total_amount) AS TotalRevenue,
    AVG(o.total_amount) AS AvgOrderValue,
    SUM(CASE WHEN o.status = 'cancelled' THEN 1 ELSE 0 END) AS CancelledOrders
FROM orders o
WHERE o.status != 'cancelled' OR o.status IS NOT NULL
GROUP BY YEAR(ordered_at), MONTH(ordered_at), DATENAME(month, ordered_at)
ORDER BY Year DESC, Month DESC;
PRINT '';

-- QUERY 2: Top 10 Best-Selling Products
PRINT 'QUERY 2: Top 10 Best-Selling Products';
PRINT '-------------------------------------';
SELECT TOP 10
    p.product_id,
    p.name AS ProductName,
    c.name AS Category,
    SUM(oi.quantity) AS UnitsSold,
    SUM(oi.line_total) AS TotalRevenue,
    COUNT(DISTINCT o.order_id) AS NumberOfOrders
FROM order_items oi
JOIN products p ON oi.product_id = p.product_id
JOIN categories c ON p.category_id = c.category_id
JOIN orders o ON oi.order_id = o.order_id
WHERE o.status = 'delivered'
GROUP BY p.product_id, p.name, c.name
ORDER BY UnitsSold DESC;
PRINT '';

-- QUERY 3: Customer Segmentation (RFM Analysis)
PRINT 'QUERY 3: Customer Segmentation';
PRINT '------------------------------';
WITH customer_metrics AS (
    SELECT 
        c.customer_id,
        c.first_name + ' ' + c.last_name AS CustomerName,
        c.email,
        COUNT(o.order_id) AS OrderCount,
        SUM(o.total_amount) AS LifetimeValue,
        MAX(o.ordered_at) AS LastOrderDate,
        DATEDIFF(day, MAX(o.ordered_at), GETDATE()) AS DaysSinceLastOrder,
        AVG(o.total_amount) AS AvgOrderValue
    FROM customers c
    LEFT JOIN orders o ON c.customer_id = o.customer_id AND o.status != 'cancelled'
    GROUP BY c.customer_id, c.first_name, c.last_name, c.email
)
SELECT 
    CustomerName,
    email,
    OrderCount,
    LifetimeValue,
    DaysSinceLastOrder,
    CASE 
        WHEN OrderCount >= 3 AND DaysSinceLastOrder <= 30 THEN 'VIP'
        WHEN OrderCount >= 2 AND DaysSinceLastOrder <= 90 THEN 'Regular'
        WHEN OrderCount >= 1 AND DaysSinceLastOrder <= 180 THEN 'Occasional'
        WHEN DaysSinceLastOrder > 180 AND OrderCount > 0 THEN 'At Risk'
        WHEN OrderCount = 0 THEN 'No Orders'
        ELSE 'New'
    END AS CustomerSegment,
    CASE
        WHEN LifetimeValue >= 1000 THEN 'Platinum'
        WHEN LifetimeValue >= 500 THEN 'Gold'
        WHEN LifetimeValue >= 100 THEN 'Silver'
        WHEN LifetimeValue > 0 THEN 'Bronze'
        ELSE 'No Purchase'
    END AS Tier
FROM customer_metrics
ORDER BY LifetimeValue DESC;
PRINT '';

-- QUERY 4: Low Stock Alert Report
PRINT 'QUERY 4: Low Stock Alert Report';
PRINT '-------------------------------';
SELECT 
    p.product_id,
    p.name AS ProductName,
    c.name AS Category,
    i.quantity_in_stock AS CurrentStock,
    i.reorder_threshold AS ReorderThreshold,
    CASE 
        WHEN i.quantity_in_stock <= 0 THEN 'OUT OF STOCK - URGENT'
        WHEN i.quantity_in_stock <= i.reorder_threshold * 0.5 THEN 'CRITICAL - Order Immediately'
        WHEN i.quantity_in_stock <= i.reorder_threshold THEN 'Low - Restock Soon'
        ELSE 'OK'
    END AS AlertLevel,
    i.last_updated AS LastInventoryUpdate
FROM inventory i
JOIN products p ON i.product_id = p.product_id
JOIN categories c ON p.category_id = c.category_id
WHERE i.quantity_in_stock <= i.reorder_threshold
ORDER BY i.quantity_in_stock ASC;
PRINT '';

-- QUERY 5: Order Status Summary Dashboard
PRINT 'QUERY 5: Order Status Summary';
PRINT '-----------------------------';
SELECT 
    status AS OrderStatus,
    COUNT(*) AS OrderCount,
    SUM(total_amount) AS TotalValue,
    AVG(total_amount) AS AvgValue,
    MIN(ordered_at) AS OldestOrder,
    MAX(ordered_at) AS NewestOrder,
    CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER() AS DECIMAL(5,2)) AS PercentageOfTotal
FROM orders
GROUP BY status
ORDER BY 
    CASE status
        WHEN 'pending' THEN 1
        WHEN 'processing' THEN 2
        WHEN 'shipped' THEN 3
        WHEN 'delivered' THEN 4
        WHEN 'cancelled' THEN 5
    END;
PRINT '';

-- QUERY 6: Product Category Performance
PRINT 'QUERY 6: Category Performance Report';
PRINT '------------------------------------';
SELECT 
    c.category_id,
    c.name AS CategoryName,
    COUNT(DISTINCT p.product_id) AS TotalProducts,
    SUM(i.quantity_in_stock) AS TotalInventory,
    SUM(oi.quantity) AS UnitsSold,
    SUM(oi.line_total) AS RevenueFromSales,
    COALESCE(SUM(oi.line_total) * 100.0 / SUM(SUM(oi.line_total)) OVER(), 0) AS RevenuePercentage
FROM categories c
LEFT JOIN products p ON c.category_id = p.category_id
LEFT JOIN inventory i ON p.product_id = i.product_id
LEFT JOIN order_items oi ON p.product_id = oi.product_id
LEFT JOIN orders o ON oi.order_id = o.order_id AND o.status = 'delivered'
WHERE c.parent_category_id IS NULL  -- Top-level categories only
GROUP BY c.category_id, c.name
ORDER BY RevenueFromSales DESC;
PRINT '';

-- QUERY 7: Customer Purchase History (detailed)
PRINT 'QUERY 7: Customer Purchase History';
PRINT '----------------------------------';
SELECT TOP 10
    c.customer_id,
    c.first_name + ' ' + c.last_name AS CustomerName,
    o.order_id,
    o.ordered_at,
    o.status,
    COUNT(oi.item_id) AS ItemsInOrder,
    o.total_amount AS OrderTotal
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
JOIN order_items oi ON o.order_id = oi.order_id
GROUP BY c.customer_id, c.first_name, c.last_name, o.order_id, o.ordered_at, o.status, o.total_amount
ORDER BY o.ordered_at DESC;
PRINT '';

-- QUERY 8: Average Delivery Time Analysis
PRINT 'QUERY 8: Average Delivery Time Analysis';
PRINT '---------------------------------------';
WITH order_processing AS (
    SELECT 
        o.order_id,
        o.ordered_at,
        p.paid_at,
        DATEDIFF(hour, o.ordered_at, p.paid_at) AS HoursToPayment,
        CASE 
            WHEN o.status = 'delivered' AND p.status = 'completed' 
            THEN DATEDIFF(day, o.ordered_at, p.paid_at)
            ELSE NULL
        END AS DaysToDelivery
    FROM orders o
    JOIN payments p ON o.order_id = p.order_id
    WHERE o.status IN ('delivered', 'shipped')
)
SELECT 
    COUNT(*) AS TotalOrdersAnalyzed,
    AVG(HoursToPayment) AS AvgHoursToPayment,
    AVG(DaysToDelivery) AS AvgDaysToDelivery,
    MIN(DaysToDelivery) AS FastestDelivery,
    MAX(DaysToDelivery) AS SlowestDelivery
FROM order_processing
WHERE DaysToDelivery IS NOT NULL;
PRINT '';

-- QUERY 9: Revenue by Payment Method
PRINT 'QUERY 9: Revenue by Payment Method';
PRINT '----------------------------------';
SELECT 
    p.method AS PaymentMethod,
    COUNT(DISTINCT p.payment_id) AS TransactionCount,
    SUM(p.amount) AS TotalAmount,
    AVG(p.amount) AS AvgTransaction,
    COUNT(DISTINCT o.order_id) AS OrderCount,
    SUM(CASE WHEN p.status = 'completed' THEN 1 ELSE 0 END) AS SuccessfulPayments,
    SUM(CASE WHEN p.status = 'failed' THEN 1 ELSE 0 END) AS FailedPayments
FROM payments p
JOIN orders o ON p.order_id = o.order_id
GROUP BY p.method
ORDER BY TotalAmount DESC;
PRINT '';

-- QUERY 10: Inventory Turnover Rate (Slow/Fast Moving Products)
PRINT 'QUERY 10: Inventory Turnover Analysis';
PRINT '-------------------------------------';
SELECT TOP 10
    p.product_id,
    p.name AS ProductName,
    i.quantity_in_stock AS CurrentStock,
    COALESCE(SUM(oi.quantity), 0) AS TotalSold,
    CASE 
        WHEN COALESCE(SUM(oi.quantity), 0) = 0 THEN 'No Sales - Dead Stock'
        WHEN i.quantity_in_stock < COALESCE(SUM(oi.quantity), 0) THEN 'Fast Moving - High Turnover'
        WHEN i.quantity_in_stock > COALESCE(SUM(oi.quantity), 0) * 2 THEN 'Slow Moving - Low Turnover'
        ELSE 'Normal Turnover'
    END AS InventoryStatus,
    COALESCE(CAST(SUM(oi.quantity) * 100.0 / NULLIF(i.quantity_in_stock + SUM(oi.quantity), 0) AS DECIMAL(5,2)), 0) AS TurnoverPercentage
FROM products p
JOIN inventory i ON p.product_id = i.product_id
LEFT JOIN order_items oi ON p.product_id = oi.product_id
LEFT JOIN orders o ON oi.order_id = o.order_id AND o.status = 'delivered'
GROUP BY p.product_id, p.name, i.quantity_in_stock
ORDER BY TurnoverPercentage ASC;
PRINT '';

PRINT '========================================';
PRINT 'All queries executed successfully.';
PRINT '';

-- ============================================================
-- PART 7: VERIFICATION QUERIES (Check data integrity)
-- ============================================================

PRINT 'DATA INTEGRITY VERIFICATION';
PRINT '============================';
PRINT '';

-- Check total records in each table
PRINT 'Record Counts by Table:';
PRINT '-----------------------';
SELECT 'customers' AS TableName, COUNT(*) AS RecordCount FROM customers
UNION ALL
SELECT 'addresses', COUNT(*) FROM addresses
UNION ALL
SELECT 'categories', COUNT(*) FROM categories
UNION ALL
SELECT 'products', COUNT(*) FROM products
UNION ALL
SELECT 'inventory', COUNT(*) FROM inventory
UNION ALL
SELECT 'orders', COUNT(*) FROM orders
UNION ALL
SELECT 'order_items', COUNT(*) FROM order_items
UNION ALL
SELECT 'payments', COUNT(*) FROM payments
UNION ALL
SELECT 'order_status_log', COUNT(*) FROM order_status_log
ORDER BY TableName;
PRINT '';

PRINT 'Orphan Record Checks (should all return 0):';
PRINT '-------------------------------------------';
SELECT 'orders without customers' AS CheckType, COUNT(*) AS OrphanCount FROM orders o WHERE NOT EXISTS (SELECT 1 FROM customers c WHERE c.customer_id = o.customer_id)
UNION ALL
SELECT 'order_items without orders', COUNT(*) FROM order_items oi WHERE NOT EXISTS (SELECT 1 FROM orders o WHERE o.order_id = oi.order_id)
UNION ALL
SELECT 'payments without orders', COUNT(*) FROM payments p WHERE NOT EXISTS (SELECT 1 FROM orders o WHERE o.order_id = p.order_id);
-- Show trigger audit log example
PRINT 'Order Status Log Sample (most recent changes):';
PRINT '----------------------------------------------';
SELECT TOP 5 
    log_id,
    order_id,
    old_status,
    new_status,
    changed_at,
    changed_by
FROM order_status_log
ORDER BY changed_at DESC;
PRINT '';

-- ============================================================
-- END OF SCRIPT
-- ============================================================
PRINT 'E-Commerce Database Setup Complete!';
PRINT 'Total tables created: 9';
PRINT 'Total triggers created: 3';
PRINT 'Total indexes created: 15+';
PRINT 'Sample customers: 10';
PRINT 'Sample products: 20';
PRINT 'Sample orders: 15';