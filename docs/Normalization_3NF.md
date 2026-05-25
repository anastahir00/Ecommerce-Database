# Normalization Documentation - Third Normal Form (3NF)

## Project Information

| Field | Detail |
|-------|--------|
| **Project** | E-Commerce Order Management System |
| **Database** | Microsoft SQL Server |
| **Date** | May 25, 2026 |
| **Author** | Muhammad Anas Tahir |

---

## What is Normalization?

Normalization is the process of organizing database tables to reduce data redundancy, eliminate anomalies, and ensure data integrity. This database is designed to achieve **Third Normal Form (3NF)**.

---

## Entity Types

### Strong Entities (Can exist independently)

| Entity | Reason |
|--------|--------|
| customers | Can exist without any other entity |
| categories | Can exist without any other entity |
| products | Can exist without any other entity |
| inventory | Can exist independently (tracked separately) |
| orders | Can exist without child records |

### Weak Entities (Depend on parent entity for existence)

| Entity | Depends On | Identifying Relationship |
|--------|------------|--------------------------|
| addresses | customers | customer_has_address |
| order_items | orders | order_contains_items |
| payments | orders | order_receives_payment |
| order_status_log | orders | order_generates_log |

---

## First Normal Form (1NF)

**Rule:** No repeating groups. Each column must contain atomic (single) values.

### Before 1NF (Violation Example)
A single orders table with multiple products stored in one row:

| order_id | customer | product1 | product2 | product3 |
|----------|----------|----------|----------|----------|
| 1001 | John | Laptop | Mouse | NULL |

**Problems:** repeating groups (product1, product2, product3), wasted space, difficult to query.

### After 1NF (Applied)
- Created separate `order_items` table
- Each product appears in its own row
- All columns contain atomic values
- No repeating groups

**Status:** ✅ **PASS**

---

## Second Normal Form (2NF)

**Rule:** No partial dependencies. All non-key columns must depend on the entire primary key.

### Before 2NF (Violation Example)
Order_items table with composite primary key (order_id, product_id) but containing product_name:

| order_id | product_id | product_name | quantity |
|----------|------------|--------------|----------|
| 1001 | 101 | Gaming Laptop | 1 |
| 1001 | 102 | Wireless Mouse | 2 |

**Problem:** `product_name` depends only on `product_id`, not on the full composite key `(order_id, product_id)`.

### After 2NF (Applied)
- Created separate `products` table
- `product_name` moved to products table
- `order_items` only contains: order_id, product_id, quantity, unit_price

**Status:** ✅ **PASS**

---

## Third Normal Form (3NF)

**Rule:** No transitive dependencies. Non-key columns cannot depend on other non-key columns.

### Before 3NF (Violations Found & Fixed)

| Violation | Problem | Fix |
|-----------|---------|-----|
| Address data in orders | city, state repeated for each order | Created `addresses` table |
| Category in products | category_name repeated for each product | Created `categories` table |
| Stock in products | stock_level mixed with product details | Created `inventory` table |

### After 3NF (Applied)

**Status:** ✅ **PASS**

---

## Final 3NF Tables (9 Tables)

| # | Table | Type | Primary Key | Foreign Key(s) |
|---|-------|------|-------------|----------------|
| 1 | customers | Strong | customer_id | - |
| 2 | addresses | Weak | address_id | customer_id |
| 3 | categories | Strong | category_id | parent_category_id (self) |
| 4 | products | Strong | product_id | category_id |
| 5 | inventory | Strong | inventory_id | product_id |
| 6 | orders | Strong | order_id | customer_id, shipping_address_id |
| 7 | order_items | Weak | item_id | order_id, product_id |
| 8 | payments | Weak | payment_id | order_id |
| 9 | order_status_log | Weak | log_id | order_id |

---

## Detailed Table Structures

**1. customers (Strong Entity)**
- PK: customer_id (INT)
- Attributes: first_name (VARCHAR), last_name (VARCHAR), email (VARCHAR), phone (VARCHAR), created_at (DATETIME)

**2. addresses (Weak Entity - depends on customers)**
- PK: address_id (INT)
- FK: customer_id (INT)
- Attributes: street (VARCHAR), city (VARCHAR), state (VARCHAR), country (VARCHAR), postal_code (VARCHAR), is_default (BIT)

**3. categories (Strong Entity - Self-Referencing)**
- PK: category_id (INT)
- FK: parent_category_id (INT)
- Attributes: name (VARCHAR)

**4. products (Strong Entity)**
- PK: product_id (INT)
- FK: category_id (INT)
- Attributes: name (VARCHAR), description (TEXT), price (DECIMAL), sku (VARCHAR), is_active (BIT), created_at (DATETIME)

**5. inventory (Strong Entity)**
- PK: inventory_id (INT)
- FK: product_id (INT)
- Attributes: quantity_in_stock (INT), reorder_threshold (INT), last_updated (DATETIME)

**6. orders (Strong Entity)**
- PK: order_id (INT)
- FK: customer_id (INT), shipping_address_id (INT)
- Attributes: order_date (DATETIME), subtotal (DECIMAL), discount (DECIMAL), tax (DECIMAL), total_amount (DECIMAL), status (VARCHAR)

**7. order_items (Weak Entity - depends on orders)**
- PK: item_id (INT)
- FK: order_id (INT), product_id (INT)
- Attributes: quantity (INT), unit_price (DECIMAL), line_total (COMPUTED)

**8. payments (Weak Entity - depends on orders)**
- PK: payment_id (INT)
- FK: order_id (INT)
- Attributes: amount (DECIMAL), method (VARCHAR), status (VARCHAR), paid_at (DATETIME)

**9. order_status_log (Weak Entity - depends on orders)**
- PK: log_id (INT)
- FK: order_id (INT)
- Attributes: old_status (VARCHAR), new_status (VARCHAR), changed_at (DATETIME), changed_by (VARCHAR)

---

## Normalization Summary

| Normal Form | Rule Applied | Status |
|-------------|--------------|--------|
| **1NF** | No repeating groups, atomic values | ✅ PASS |
| **2NF** | No partial dependencies | ✅ PASS |
| **3NF** | No transitive dependencies | ✅ PASS |

---

## Benefits of 3NF

| Benefit | Description |
|---------|-------------|
| **No Data Redundancy** | Each piece of data stored once |
| **No Update Anomalies** | Changing data requires one update |
| **No Insertion Anomalies** | Can insert new data without unrelated data |
| **No Deletion Anomalies** | Deleting data doesn't lose unrelated information |
| **Referential Integrity** | Foreign keys maintain relationships |

---

## Example: Transitive Dependency Fixed

**Before 3NF (Violation):** orders table with transitive dependency: order_id, customer_id, customer_city, customer_state

**Problem:** customer_city and customer_state depend on customer_id, not on order_id

**After 3NF (Fixed):** customers (customer_id, first_name, last_name, email), addresses (address_id, customer_id, city, state, country), orders (order_id, customer_id, shipping_address_id)

Now city and state depend on address_id, which is properly linked to the order through shipping_address_id.

---

## Conclusion

The E-Commerce Order Management System database is fully normalized to **Third Normal Form (3NF)**, ensuring:
- ✅ Minimal data redundancy
- ✅ Consistent data integrity
- ✅ Efficient query performance
- ✅ Scalable database design
- ✅ Professional industry-standard structure

---

## Document Version

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | May 25, 2026 | Initial 3NF documentation with 9 tables, strong/weak entities, and normalization proof 