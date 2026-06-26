-- ============================================================================
-- Day 5 — SQL Advanced & Tuning
-- CTEs · recursive CTEs · pivot · indexes · EXPLAIN · query optimisation
-- Week 1 · Foundations
-- Author: Dinesh Kanna KV
-- ============================================================================
-- Engine: PostgreSQL (local). LeetCode problems submitted as PostgreSQL.
-- Practice tables (departments, employees, customers, orders, big_emp) come
-- from the Day 2 setup script.
-- ============================================================================


-- ============================================================================
-- §1–2  CTEs — staged, readable pipelines
-- ============================================================================

-- Basic CTE: average of the per-department salary totals.
-- (Day 3 derived-table rewritten as a named CTE.)
WITH dept_totals AS (
    SELECT dept_id, SUM(salary) AS total
    FROM employees
    GROUP BY dept_id
)
SELECT AVG(total) AS avg_dept_total
FROM dept_totals;                       -- expect 176666.67

-- Chained CTEs: rank departments by total spend, keep the top 2.
-- Note: the RANK() is filtered in the OUTER query, not where it is computed
-- (execution order — WHERE runs before SELECT builds the window column).
WITH dept_totals AS (
    SELECT dept_id, SUM(salary) AS total
    FROM employees
    GROUP BY dept_id
),
ranked AS (
    SELECT dept_id, total,
           RANK() OVER (ORDER BY total DESC) AS spend_rank
    FROM dept_totals
)
SELECT * FROM ranked WHERE spend_rank <= 2;


-- ============================================================================
-- §4  Recursive CTEs  (Lab 11)
-- Two parts joined by UNION ALL: base case (runs once) + recursive step
-- (self-references the CTE, runs until it returns ZERO new rows).
-- ============================================================================

-- (a) Number generator 1..10. Stops when the step on n=10 fails 10 < 10.
WITH RECURSIVE nums AS (
    SELECT 1 AS n                          -- base: seed
    UNION ALL
    SELECT n + 1 FROM nums WHERE n < 10     -- step: +1, terminating predicate
)
SELECT n FROM nums;                         -- expect 1..10

-- (b) Org hierarchy with depth, rooted at the CEO.
--     Walks DOWNWARD: manager -> reports, via e.manager_id = o.emp_id.
--     (Flip to o.manager_id = e.emp_id to walk UPWARD to the CEO.)
WITH RECURSIVE org AS (
    SELECT emp_id, name, manager_id, 1 AS level     -- base: CEO (no manager)
    FROM employees
    WHERE manager_id IS NULL
    UNION ALL
    SELECT e.emp_id, e.name, e.manager_id, o.level + 1   -- step: direct reports
    FROM employees e
    JOIN org o ON e.manager_id = o.emp_id
)
SELECT level, name FROM org ORDER BY level, name;
-- expect: L1 Asha | L2 Meera,Ravi,Sahil | L3 Divya,Karthik
-- Recursion stops at round 3: Divya/Karthik have no reports -> empty round.
-- Defence on real data that might contain a cycle: add a depth cap, e.g.
--   ... JOIN org o ON e.manager_id = o.emp_id  WHERE o.level < 100


-- ============================================================================
-- §5  Pivot — long -> wide via conditional aggregation (SUM(CASE ...))
-- No portable PIVOT keyword in Postgres/MySQL; this CASE form is the answer.
-- Count employees per salary band, one column per band, one row per dept.
-- ============================================================================
SELECT dept_id,
       SUM(CASE WHEN salary >= 100000                       THEN 1 ELSE 0 END) AS high,
       SUM(CASE WHEN salary >= 75000 AND salary < 100000    THEN 1 ELSE 0 END) AS mid,
       SUM(CASE WHEN salary <  75000                        THEN 1 ELSE 0 END) AS entry
FROM employees
GROUP BY dept_id;
-- expect: 10 -> 1,2,0 | 20 -> 0,1,1 | NULL -> 0,0,1


-- ============================================================================
-- §9  Top-N per group — the senior pattern: CTE + window function
-- "Top 2 earners per department, ties handled, written readably."
-- DENSE_RANK so ties share a rank; NULL-dept filtered out (Day 2 NULL rule).
-- Generalises to top-N by changing <= 2.
-- ============================================================================
WITH ranked AS (
    SELECT name, dept_id, salary,
           DENSE_RANK() OVER (PARTITION BY dept_id ORDER BY salary DESC) AS rnk
    FROM employees
    WHERE dept_id IS NOT NULL
)
SELECT dept_id, name, salary
FROM ranked
WHERE rnk <= 2
ORDER BY dept_id, salary DESC;


-- ============================================================================
-- §6–8  TUNING EVIDENCE — before/after EXPLAIN ANALYZE  (Labs 12 & 13)
-- Run against big_emp (500k rows). ANALYZE first to refresh planner stats.
-- This is the portfolio centrepiece: it proves I can MEASURE a query, not
-- just write one. Real numbers from my run are recorded in the comments.
-- ============================================================================

ANALYZE big_emp;

-- ---- Lab 12: missing index -> Seq Scan; add index -> Index Scan -------------

-- BEFORE (no index): Parallel Seq Scan, reads ~500k rows to keep 3.
--   EXPLAIN ANALYZE SELECT * FROM big_emp WHERE salary = 50000;
--   -> Parallel Seq Scan on big_emp
--        Filter: (salary = 50000)
--        Rows Removed by Filter: 249998   (per worker x2 ~= 500k total)
--      Execution Time: ~30.0 ms
EXPLAIN ANALYZE SELECT * FROM big_emp WHERE salary = 50000;

CREATE INDEX IF NOT EXISTS idx_big_emp_salary ON big_emp (salary);
ANALYZE big_emp;

-- AFTER (index): Bitmap Index Scan, touches only the 3 matching rows.
--   -> Bitmap Index Scan on idx_big_emp_salary
--        Index Cond: (salary = 50000)     <- label flips Filter -> Index Cond
--      Heap Blocks: exact=3
--      Execution Time: ~0.70 ms           (~43x faster, SAME select list)
EXPLAIN ANALYZE SELECT * FROM big_emp WHERE salary = 50000;

-- WHAT CHANGED & WHY: only an index was added — the SELECT list was identical
-- in both runs. Rows scanned collapsed 500k -> 3 and time dropped ~43x.
-- Proof that rows-scanned is governed by WHERE + index availability, NOT by
-- the number of columns selected.

-- ---- Lab 13: sargability — a function on the column kills the index --------

-- NON-SARGABLE: arithmetic on the indexed column -> index unusable -> Seq Scan.
--   Filter: ((salary + 0) = 50000)   Execution Time: ~31.7 ms
--   Also note rows estimate goes bad (est ~2500 vs actual 3): wrapping the
--   column loses the planner's column statistics for that expression.
EXPLAIN ANALYZE SELECT * FROM big_emp WHERE salary + 0 = 50000;

-- NON-SARGABLE: function on the indexed column -> Seq Scan.
--   Filter: (abs(salary) = 50000)    Execution Time: ~35.6 ms
EXPLAIN ANALYZE SELECT * FROM big_emp WHERE ABS(salary) = 50000;

-- SARGABLE: column left bare, maths moved to the constant side -> Index Scan.
--   Index Cond: (salary = 50000)     Execution Time: ~0.03 ms
-- Same rows as the non-sargable versions; ~900x faster on phrasing alone.
EXPLAIN ANALYZE SELECT * FROM big_emp WHERE salary = 50000 + 0;

-- Real-world form of the same trap and its fix:
--   BAD : WHERE YEAR(order_date) = 2019
--   GOOD: WHERE order_date >= '2019-01-01' AND order_date < '2020-01-01'


-- ============================================================================
-- §3 + §8  Lab 14 — correlated subquery vs set-based rewrite
-- Both return Asha and Meera. The correlated plan shows SubPlan loops=6
-- (inner query re-runs once per outer row -> does not scale). The CTE+join
-- computes all dept averages once (HashAggregate loops=1) then joins.
-- ============================================================================

-- Correlated (Day 3 §7): inner AVG recomputed for every outer row.
EXPLAIN ANALYZE
SELECT e.name, e.salary, e.dept_id
FROM employees e
WHERE e.salary > (
    SELECT AVG(e2.salary) FROM employees e2 WHERE e2.dept_id = e.dept_id
);

-- Set-based: averages computed ONCE in a CTE, then joined.
EXPLAIN ANALYZE
WITH dept_avg AS (
    SELECT dept_id, AVG(salary) AS avg_sal
    FROM employees
    GROUP BY dept_id
)
SELECT e.name, e.salary, e.dept_id
FROM employees e
JOIN dept_avg d ON e.dept_id = d.dept_id
WHERE e.salary > d.avg_sal;
-- Tuning note: on 6 rows both are instant; the correlated penalty is invisible
-- at small scale (loops=6) and lethal at large scale (loops=N over the table).
-- Diagnose by plan SHAPE (loops=N), not by timing toy data.


-- ============================================================================
-- Problem 15 (capstone) — 601. Human Traffic of Stadium
-- Stadium(id, visit_date, people): 3+ consecutive ids each with people >= 100.
-- Filter FIRST inside the CTE, then LAG/LEAD two rows each way (Day 4), then
-- flag a row that is the start / middle / end of a length-3 consecutive run.
-- Accepted on LeetCode 15/15 (PostgreSQL).
-- ============================================================================
WITH enriched AS (
    SELECT id, visit_date, people
    FROM Stadium
    WHERE people >= 100                       -- filter first: gaps are intentional
),
flagged AS (
    SELECT id, visit_date, people,
           LAG(id, 1)  OVER (ORDER BY id) AS prev1,
           LAG(id, 2)  OVER (ORDER BY id) AS prev2,
           LEAD(id, 1) OVER (ORDER BY id) AS next1,
           LEAD(id, 2) OVER (ORDER BY id) AS next2
    FROM enriched
)
SELECT id, visit_date, people
FROM flagged
WHERE (next1 - id = 1 AND next2 - id = 2)      -- this row STARTS a run
   OR (id - prev1 = 1 AND next1 - id = 1)      -- this row is the MIDDLE
   OR (id - prev1 = 1 AND id - prev2 = 2)      -- this row ENDS a run
ORDER BY visit_date;

-- ----------------------------------------------------------------------------
-- As actually submitted on LeetCode (also Accepted). Kept for honesty.
-- This filters people>=100 in the OUTER WHERE; because AND binds tighter than
-- OR, the >=100 guard only attaches to the first branch and the gap is closed
-- by the run-logic in the other branches. The CTE-filtered version above is
-- the robust pattern (every row in `enriched` already qualifies).
-- ----------------------------------------------------------------------------
-- with enriched as (
--     select id, visit_date, people,
--            lag(people, 1)  over (order by id) as prev1,
--            lag(people, 2)  over (order by id) as prev2,
--            lead(people, 1) over (order by id) as next1,
--            lead(people, 2) over (order by id) as next2
--     from stadium
-- )
-- select distinct id, visit_date, people
-- from enriched
-- where people >= 100
--   and ((next1 >= 100 and next2 >= 100)
--    or  (prev1 >= 100 and next1 >= 100)
--    or  (prev1 >= 100 and prev2 >= 100))
-- order by id;
