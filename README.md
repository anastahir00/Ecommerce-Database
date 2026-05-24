# E-Commerce Order Management System - Database Design

## Project Information

| Field | Detail |
|-------|--------|
| **Course** | Database Systems (CC230L) |
| **Instructor** | Sir Shahzaib Mushtaq Shah |
| **Submission Date** | May 15, 2026 |

## Team Members

| Name | Student ID |
|------|------------|
| Muhammad Anas Tahir | F2024266985 |
| Muhammad Talha Bhatti | F2024266503 |
| Zohaib Ahmad | F2024266251 |
| Maniha Ashraf | F20242661269 |

## Project Overview

Relational database design for an E-Commerce Order Management System using Microsoft SQL Server and T-SQL. Models complete lifecycle of online retail transactions from customer registration through order placement, payment, and inventory updates.

## Database Schema (9 Tables)

| Table | Description |
|-------|-------------|
| customers | Customer information (6 columns) |
| addresses | Shipping/billing addresses (7 columns) |
| categories | Product hierarchy (self-referencing) (3 columns) |
| products | Product catalog (7 columns) |
| inventory | Stock tracking (5 columns) |
| orders | Order header (9 columns) |
| order_items | Line items with computed column (6 columns) |
| payments | Transaction records (6 columns) |
| order_status_log | Audit trail (5 columns) |

## Key Technical Features

| Feature | Description |
|---------|-------------|
| Normalization | 3NF design |
| Triggers | Inventory decrement + Order status audit |
| Computed Column | line_total AS (quantity * unit_price) PERSISTED |
| Self-Referencing | categories (parent_category_id) |
| Analytical Queries | Monthly revenue, top products, customer segmentation, low stock alerts |

## Deliverables

- [x] Project Proposal Document
- [ ] ER Diagram (draw.io)
- [ ] Complete SQL Schema
- [ ] Triggers Implementation
- [ ] Stored Procedures
- [ ] Sample Data (50+ rows per table)
- [ ] Analytical Queries
- [ ] Final Report

## Related Projects

- [OOP E-Commerce System](https://github.com/anastahir00/OOP-Ecommerce-System)
- [DSA E-Commerce System](https://github.com/anastahir00/Ecommerce-DSA)

## Next Phase

Complete SQL implementation and C# .NET desktop application.