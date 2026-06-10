-- =====================================================================
-- Day 02 — SQL Joins Practice
-- Week 1 (Foundations) · AWS Data Engineer prep
-- Topics: INNER / LEFT / RIGHT / FULL joins · table aliases · self-joins
--         · anti-joins · CROSS join
-- =====================================================================
-- Progress: 10 / 20 study-pack problems solved (problems 1–9 and 15).
-- Deferred to after Day 3–4 (aggregation / window functions): 10–14, 16–20.
-- =====================================================================


-- =====================================================================
-- PART A — Local practice schema (DBeaver / PostgreSQL)
-- Runs unchanged in MySQL. Used for hands-on exploration of every join type.
-- =====================================================================

CREATE TABLE departments (
    dept_id   INT PRIMARY KEY,
    dept_name VARCHAR(40),
    city      VARCHAR(40)
);
INSERT INTO departments VALUES
(10, 'Engineering', 'Bengaluru'),
(20, 'Sales',       'Chennai'),
(30, 'Marketing',   'Mumbai'),
(40, 'Research',    'Hyderabad');

CREATE TABLE employees (
    emp_id     INT PRIMARY KEY,
    name       VARCHAR(40),
    dept_id    INT,
    manager_id INT,
    salary     INT
);
INSERT INTO employees VALUES
(1, 'Asha',    10, NULL, 150000),
(2, 'Ravi',    10, 1,    90000),
(3, 'Meera',   20, 1,    85000),
(4, 'Karthik', 20, 3,    60000),
(5, 'Divya',   10, 2,    75000),
(6, 'Sahil',   NULL, 1,  70000);

CREATE TABLE customers (
    cust_id      INT PRIMARY KEY,
    name         VARCHAR(40),
    credit_limit INT
);
INSERT INTO customers VALUES
(1, 'Anil',   1000),
(2, 'Bhavna', 2000),
(3, 'Chetan', 1500),
(4, 'Deepa',  3000);

CREATE TABLE orders (
    order_id INT PRIMARY KEY,
    cust_id  INT,
    amount   INT
);
INSERT INTO orders VALUES
(101, 1, 500),
(102, 1, 300),
(103, 2, 700);


-- =====================================================================
-- PART B — LeetCode solutions (PostgreSQL). All accepted.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. LeetCode 175 — Combine Two Tables                [LEFT JOIN]
--    Every person must appear, address or not -> LEFT JOIN.
-- ---------------------------------------------------------------------
SELECT p.firstName, p.lastName, a.city, a.state
FROM Person p
LEFT JOIN Address a ON p.personId = a.personId;


-- ---------------------------------------------------------------------
-- 2. LeetCode 1378 — Replace Employee ID With The Unique Identifier
--                                                     [LEFT JOIN + NULL passthrough]
--    All employees kept; missing unique_id comes back NULL.
-- ---------------------------------------------------------------------
SELECT u.unique_id, e.name
FROM Employees e
LEFT JOIN EmployeeUNI u ON e.id = u.id;


-- ---------------------------------------------------------------------
-- 3. LeetCode 1068 — Product Sales Analysis I          [INNER JOIN]
--    Only sales, every sale has a product -> plain INNER JOIN.
-- ---------------------------------------------------------------------
SELECT p.product_name, s.year, s.price
FROM Sales s
JOIN Product p ON s.product_id = p.product_id;


-- ---------------------------------------------------------------------
-- 4. LeetCode 577 — Employee Bonus                     [LEFT JOIN + NULL filter]
--    Include employees with no bonus row; NULL < 1000 is UNKNOWN,
--    so the OR ... IS NULL is mandatory to keep them.
-- ---------------------------------------------------------------------
SELECT e.name, b.bonus
FROM Employee e
LEFT JOIN Bonus b ON e.empId = b.empId
WHERE b.bonus < 1000 OR b.bonus IS NULL;


-- ---------------------------------------------------------------------
-- 5. LeetCode 1581 — Customer Who Visited but Did Not Make Any Transactions
--                                                     [LEFT anti-join + GROUP BY]
--    Anti-join: keep visits with no matching transaction, then count.
--    COUNT(*) (not COUNT(col)) because every surviving row is a real visit.
-- ---------------------------------------------------------------------
SELECT v.customer_id, COUNT(*) AS count_no_trans
FROM Visits v
LEFT JOIN Transactions t ON v.visit_id = t.visit_id
WHERE t.transaction_id IS NULL
GROUP BY v.customer_id;


-- ---------------------------------------------------------------------
-- 6. LeetCode 183 — Customers Who Never Order          [Anti-join]
--    LEFT JOIN then keep rows where the order side is NULL.
-- ---------------------------------------------------------------------
SELECT c.name AS Customers
FROM Customers c
LEFT JOIN Orders o ON c.id = o.customerId
WHERE o.customerId IS NULL;


-- ---------------------------------------------------------------------
-- 7. LeetCode 607 — Sales Person                       [Anti-join via subquery]
--    Inner query = everyone who sold to 'RED'; outer NOT IN = the rest.
--    Reasons about each person's whole order history (not row-by-row).
-- ---------------------------------------------------------------------
SELECT s.name
FROM SalesPerson s
WHERE s.sales_id NOT IN (
    SELECT o.sales_id
    FROM Orders o
    JOIN Company c ON o.com_id = c.com_id
    WHERE c.name = 'RED'
);


-- ---------------------------------------------------------------------
-- 8. LeetCode 181 — Employees Earning More Than Their Managers
--                                                     [Self-join]
--    e = worker, m = manager, joined on e.managerId = m.id.
--    (LEFT JOIN works here because WHERE e.salary > m.salary drops the
--     NULL-manager rows anyway; INNER JOIN is the more idiomatic choice.)
-- ---------------------------------------------------------------------
SELECT e.name AS Employee
FROM Employee e
LEFT JOIN Employee m ON e.managerId = m.id
WHERE e.salary > m.salary;


-- ---------------------------------------------------------------------
-- 9. LeetCode 197 — Rising Temperature                 [Self-join on date+1]
--    Join today's row to yesterday's by DATE, never by id order.
-- ---------------------------------------------------------------------
SELECT w.id
FROM Weather w
JOIN Weather y ON w.recordDate = y.recordDate + INTERVAL '1 day'
WHERE w.temperature > y.temperature;


-- ---------------------------------------------------------------------
-- 15. LeetCode 180 — Consecutive Numbers               [Triple self-join]
--     Three copies of Logs chained by id: a -> b (id+1) -> c (id+1),
--     all sharing the same num => a number appearing 3+ times in a row.
--     DISTINCT collapses overlapping triples from runs of 4+.
--     (Window-function LAG() is the scalable alternative — see Day 4.)
-- ---------------------------------------------------------------------
SELECT DISTINCT a.num AS ConsecutiveNums
FROM Logs a
JOIN Logs b ON b.id = a.id + 1 AND a.num = b.num
JOIN Logs c ON c.id = b.id + 1 AND a.num = c.num;


-- =====================================================================
-- DEFERRED (return after Day 3 aggregation / Day 4 window functions):
--   10. 1661 Average Time of Process per Machine   (self-join + AVG)
--   11. 1731 Employees Which Report to Each Employee (self-join + COUNT/AVG)
--   12. 1280 Students and Examinations             (CROSS JOIN + LEFT + COUNT)
--   13.  570 Managers with >= 5 Direct Reports      (self-join + HAVING)
--   14. 1934 Confirmation Rate                      (LEFT JOIN + AVG(CASE))
--   16.  184 Department Highest Salary              (JOIN + subquery MAX)
--   17. 1158 Market Analysis I                      (LEFT JOIN, filter-in-ON)
--   18.  550 Game Play Analysis IV                  (self-join + MIN subquery)
--   19.  512 Game Play Analysis II                  (JOIN to MIN subquery)
--   20.  262 Trips and Users                        (multi-join + SUM(CASE))
-- =====================================================================
