# ER Diagram Documentation - E-Commerce Database

## Entity Relationship Diagram

![ER Diagram](ER_Diagram.png)

---

## Legend / Symbols

| Symbol | Meaning |
|--------|---------|
| **PK** | Primary Key - Uniquely identifies each record |
| **FK** | Foreign Key - References PK of another table |
| *** (asterisk)** | Derived Attribute - Calculated from other attributes |
| **1** | One (cardinality) |
| **M** | Many (cardinality) |

---

## Entities (9 Tables)

| # | Entity | Type | Primary Key | Foreign Key(s) |
|---|--------|------|-------------|----------------|
| 1 | customers | Strong | customer_id | - |
| 2 | addresses | Weak | address_id | customer_id |
| 3 | categories | Strong | category_id | parent_category_id (self) |
| 4 | products | Strong | product_id | category_id |
| 5 | inventory | Strong | inventory_id | product_id |
| 6 | orders | Strong | order_id | customer_id, address_id |
| 7 | order_items | Weak | item_id | order_id, product_id |
| 8 | payments | Weak | payment_id | order_id |
| 9 | order_status_log | Weak | log_id | order_id |

---

## Attributes by Entity

### customers (Strong)
- customer_id (PK)
- name
- phone
- email
- password
- created_at

### addresses (Weak)
- address_id (PK)
- customer_id (FK)
- city
- is_default

### categories (Strong)
- category_id (PK)
- name
- parent_category_id (FK self)

### products (Strong)
- product_id (PK)
- category_id (FK)
- name
- description
- price
- sku
- created_at

### inventory (Strong)
- inventory_id (PK)
- product_id (FK)
- quantity
- reorder_threshold

### orders (Strong)
- order_id (PK)
- customer_id (FK)
- address_id (FK)
- order_date
- total_amount (*Derived)
- status
- created_at
- updated_at

### order_items (Weak)
- item_id (PK)
- order_id (FK)
- product_id (FK)
- quantity
- unit_price
- line_total (*Derived)

### payments (Weak)
- payment_id (PK)
- order_id (FK)
- amount
- method
- payment_status
- paid_at

### order_status_log (Weak)
- log_id (PK)
- order_id (FK)
- old_status
- new_status
- changed_at

---

## Relationships

| Relationship | From | To | Cardinality |
|--------------|------|-----|-------------|
| HAS | customers | addresses | 1 : M |
| PLACES | customers | orders | 1 : M |
| SHIP TO | orders | addresses | M : 1 |
| INCLUDES | orders | order_items | 1 : M |
| APPEARS IN | products | order_items | 1 : M |
| PAID | orders | payments | 1 : 1 |
| LOGGED IN | orders | order_status_log | 1 : M |
| CONTAINS | categories | products | 1 : M |
| TRACKED BY | products | inventory | 1 : 1 |

---

## Derived Attributes

| Entity | Attribute | Calculation |
|--------|-----------|-------------|
| orders | total_amount | Sum of order_items.line_total + tax - discount |
| order_items | line_total | quantity × unit_price |

---

## Notes

- **Weak Entities**: addresses, order_items, payments, order_status_log depend on their parent entity for existence
- **Self-Referencing**: categories has parent_category_id for hierarchical structure
- **One-to-One**: payments (1:1 with orders), inventory (1:1 with products)

---

*Generated: June 10, 2026*