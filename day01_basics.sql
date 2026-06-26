-- ============================================
-- Day 1 - SQL Basics
-- Topics: SELECT, WHERE, ORDER BY, DISTINCT, GROUP BY vs HAVING
-- ============================================

-- Setup: practice table
CREATE TABLE orders (
    order_id    INT,
    customer_id INT,
    country     VARCHAR(50),
    amount      INT
);

INSERT INTO orders VALUES
(1, 101, 'India', 500),
(2, 102, 'India', 1200),
(3, 101, 'UK', 300),
(4, 103, 'India', 1200),
(5, 102, 'UK', 900);

-- Q1: Distinct countries with at least one order over 1000, alphabetical. Returns: India
SELECT DISTINCT country
FROM orders
WHERE amount > 1000
ORDER BY country ASC;

-- Q2: How many rows + why? Returns 5.
-- DISTINCT dedups on the FULL set of selected columns (the whole row),
-- so a row is duplicate only if BOTH customer_id AND country match. All 5 pairs are unique.
SELECT DISTINCT customer_id, country
FROM orders;

-- WHERE vs HAVING -------------------------------------------------

-- (WRONG) "every order over 1000": WHERE drops small orders BEFORE grouping.
-- Returns India - which is incorrect (India has a 500 order).
SELECT country
FROM orders
WHERE amount > 1000
GROUP BY country;

-- (CORRECT) "every order over 1000": test a group-level aggregate.
-- If the MIN order in a country is > 1000, all of them are. Returns: empty.
SELECT country
FROM orders
GROUP BY country
HAVING MIN(amount) > 1000;

-- Postgres note: COUNT(DISTINCT customer_id, country) ERRORS in Postgres.
-- Wrap columns in a tuple instead. Returns: 5
SELECT COUNT(DISTINCT (customer_id, country))
FROM orders;

-- KEY TAKEAWAY:
-- WHERE filters rows BEFORE grouping. HAVING filters groups AFTER grouping.
-- Clause order: FROM -> WHERE -> GROUP BY -> HAVING -> SELECT -> ORDER BY