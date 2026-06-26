-- =============================================================
-- Day 4 — SQL Window Functions
-- Week 1 · Foundations · de-learning-journey
-- Repo path: sql/day04_window_functions.sql
-- Platform: PostgreSQL (DBeaver local) + LeetCode (PostgreSQL judge)
-- Status: 12/15 accepted on LeetCode; problems 11, 13, 15 = premium
-- =============================================================

-- -------------------------------------------------------------
-- PART A — Practice schema (run once in DBeaver)
-- Reuses employees + departments from Day 2/3.
-- Add the time-series table below for LAG/LEAD and running-total demos.
-- -------------------------------------------------------------

-- Verify Day 2/3 tables are alive:
-- SELECT count(*) FROM employees;   -- expect 6

CREATE TABLE IF NOT EXISTS monthly_sales (
    sale_month DATE,
    region     VARCHAR(20),
    revenue    INT
);
INSERT INTO monthly_sales VALUES
('2024-01-01', 'North', 100),
('2024-02-01', 'North', 100),   -- tie: exposes ROW_NUMBER vs RANK vs DENSE_RANK
('2024-03-01', 'North', 250),
('2024-01-01', 'South', 200),
('2024-02-01', 'South',  50),
('2024-03-01', 'South', 300);


-- =============================================================
-- PROBLEM 1 — Rising Temperature (LC 197)
-- Skill: LAG + date-adjacency check (redo of Day 2 #9 self-join)
-- Key lesson: LAG removes the self-join but date-adjacency check
--             is still mandatory — "previous row" ≠ "yesterday"
--             if dates have gaps.
-- Accepted: 15/15 test cases
-- =============================================================

SELECT id
FROM (
    SELECT id,
           recordDate,
           temperature,
           LAG(temperature) OVER (ORDER BY recordDate) AS prev_temp,
           LAG(recordDate)  OVER (ORDER BY recordDate) AS prev_date
    FROM Weather
) d
WHERE temperature > prev_temp
  AND recordDate = prev_date + INTERVAL '1 day';

-- MySQL dialect: replace INTERVAL '1 day' with DATE_ADD(prev_date, INTERVAL 1 DAY)


-- =============================================================
-- PROBLEM 2 — Second Highest Salary (LC 176)
-- Skill: DENSE_RANK + MAX wrapper for NULL-when-none requirement
-- Key lesson: MAX over an empty set returns NULL automatically —
--             same trick as Day 3 #5 (Biggest Single Number).
-- Accepted: 10/10 test cases
-- =============================================================

SELECT MAX(salary) AS SecondHighestSalary
FROM (
    SELECT salary,
           DENSE_RANK() OVER (ORDER BY salary DESC) AS rnk
    FROM Employee
) rnkSalary
WHERE rnk = 2;


-- =============================================================
-- PROBLEM 3 — Rank Scores (LC 178)
-- Skill: DENSE_RANK one-liner — "ties share, no gaps" = DENSE_RANK
-- Key lesson: "no gaps after a tie" is the literal definition of
--             DENSE_RANK; RANK would give 1,1,3 here instead of 1,1,2.
-- Accepted: 11/11 test cases
-- =============================================================

SELECT score,
       DENSE_RANK() OVER (ORDER BY score DESC) AS "rank"
FROM Scores;

-- Note: "rank" is a reserved word — double-quote in Postgres,
--       single-quote alias in MySQL: AS 'rank'


-- =============================================================
-- PROBLEM 4 — Nth Highest Salary (LC 177)
-- Skill: DENSE_RANK generalised to N inside a Postgres function
-- Key lesson: the window logic is identical to problem 2 — just
--             swap the hardcoded 2 for the parameter N.
-- Accepted: 18/18 test cases
-- =============================================================

CREATE OR REPLACE FUNCTION NthHighestSalary(N INT) RETURNS TABLE (Salary INT) AS $$
BEGIN
    RETURN QUERY (
        SELECT DISTINCT sal
        FROM (
            SELECT e.salary AS sal,
                   DENSE_RANK() OVER (ORDER BY e.salary DESC) AS rnk
            FROM Employee e
        ) AS rnkSalary
        WHERE rnk = N
    );
END;
$$ LANGUAGE plpgsql;

-- MySQL version: wrap in CREATE FUNCTION ... RETURNS INT with
--               SELECT DISTINCT salary ... WHERE rnk = N inside BEGIN/RETURN/END


-- =============================================================
-- PROBLEM 5 — Consecutive Numbers (LC 180)
-- Skill: double LAG (redo of Day 2 #15 triple self-join)
-- Key lesson: LAG(col, k) looks back k rows — triple self-join
--             collapses to one clean scan. DISTINCT because a run
--             of 4+ produces overlapping triples.
-- Accepted: 23/23 test cases | Beats 70.98% runtime
-- =============================================================

SELECT DISTINCT num AS ConsecutiveNums
FROM (
    SELECT id,
           num,
           LAG(num, 1) OVER (ORDER BY id) AS next_num,
           LAG(LAG(num) OVER ()) OVER ()  AS next_next_num   -- your submitted version
    FROM Logs
) enriched
WHERE num = next_num
  AND next_num = next_next_num;

-- Cleaner single-CTE alternative (same result, one fewer scan level):
-- WITH t AS (
--     SELECT num,
--            LAG(num, 1) OVER (ORDER BY id) AS p1,
--            LAG(num, 2) OVER (ORDER BY id) AS p2
--     FROM Logs
-- )
-- SELECT DISTINCT num AS ConsecutiveNums FROM t WHERE num = p1 AND num = p2;


-- =============================================================
-- PROBLEM 6 — Department Highest Salary (LC 184)
-- Skill: RANK + PARTITION BY + CTE filter (redo of Day 3 #11 subquery)
-- Key lesson: RANK (not ROW_NUMBER) so tied top earners both survive.
--             CTE wrapper needed because WHERE can't filter window
--             results in the same query level (execution step 2 vs 5).
-- Accepted: solved with me during session
-- =============================================================

WITH ranked AS (
    SELECT e.name       AS Employee,
           e.salary,
           e.departmentId,
           RANK() OVER (PARTITION BY e.departmentId ORDER BY e.salary DESC) AS rnk
    FROM Employee e
)
SELECT d.name AS Department,
       r.Employee,
       r.salary AS Salary
FROM ranked r
JOIN Department d ON r.departmentId = d.id
WHERE r.rnk = 1;


-- =============================================================
-- PROBLEM 7 — Game Play Analysis III (LC 534)
-- Skill: SUM() OVER (PARTITION BY … ORDER BY) = running total
-- Key lesson: ORDER BY inside OVER flips the frame to
--             "start of partition → current row" = cumulative sum.
--             Without ORDER BY every row would show the grand total.
-- Accepted: solved with me during session
-- =============================================================

SELECT player_id,
       event_date,
       SUM(games_played) OVER (
           PARTITION BY player_id
           ORDER BY event_date
       ) AS games_played_so_far
FROM Activity;


-- =============================================================
-- PROBLEM 8 — Running Total for Different Genders (LC 1308)
-- Skill: aggregate-first in CTE, then SUM() OVER window
-- Key lesson: when raw data has multiple rows per (partition key, date),
--             collapse them FIRST in a CTE, THEN window over clean rows.
--             Windowing before grouping gives fragile accidental-correct output.
-- Accepted: local DBeaver (premium on LeetCode)
-- =============================================================

WITH daily AS (
    SELECT gender,
           day,
           SUM(score_points) AS day_total
    FROM Scores
    GROUP BY gender, day
)
SELECT gender,
       day,
       SUM(day_total) OVER (
           PARTITION BY gender
           ORDER BY day
       ) AS total
FROM daily
ORDER BY gender, day;


-- =============================================================
-- PROBLEM 9 — Game Play Analysis IV (LC 550)
-- Skill: MIN() OVER + LEAD + date-adjacency (redo of Day 3 #14)
-- Key lesson: MIN(event_date) OVER (PARTITION BY player_id) stamps
--             each player's first date on every row without a derived
--             table. WHERE event_date = first_date keeps only the
--             first-login row. LEAD then peeks at next login.
--             Single-login players get LEAD = NULL → filtered out
--             of numerator automatically (NULL ≠ any date).
-- Accepted: 15/15 test cases | your independent solution
-- =============================================================

SELECT ROUND(
    COUNT(DISTINCT player_id) FILTER (
        WHERE next_date = first_date + INTERVAL '1 day'
    )::numeric
    / COUNT(DISTINCT player_id), 2
) AS fraction
FROM (
    SELECT player_id,
           event_date,
           MIN(event_date)  OVER (PARTITION BY player_id)              AS first_date,
           LEAD(event_date) OVER (PARTITION BY player_id ORDER BY event_date) AS next_date
    FROM Activity
) AS enriched
WHERE event_date = first_date;

-- Note: after WHERE event_date = first_date, exactly one row per player
-- survives, so COUNT(DISTINCT player_id) = COUNT(*) at that point.
-- COUNT(*) is slightly cheaper and equally correct here.

-- MySQL dialect: use DATE_ADD(first_date, INTERVAL 1 DAY) for date math.


-- =============================================================
-- PROBLEM 10 — Exchange Seats (LC 626)
-- Skill: LEAD + LAG + CASE for neighbour-swap
-- Key lesson: LEAD/LAG express "swap with neighbour" with no self-join.
--             Only special case: last odd-numbered seat has no LEAD →
--             keep its own student instead of getting NULL.
-- Accepted: 14/14 test cases
-- =============================================================

SELECT id,
       CASE
           WHEN id % 2 = 1 AND id = (SELECT MAX(id) FROM Seat)
               THEN student                              -- last odd seat: no swap
           WHEN id % 2 = 1
               THEN LEAD(student) OVER (ORDER BY id)    -- odd: take next student
           ELSE
               LAG(student)  OVER (ORDER BY id)         -- even: take prev student
       END AS student
FROM Seat
ORDER BY id;


-- =============================================================
-- PROBLEM 11 — Median Employee Salary (LC 569) ★ PREMIUM
-- Skill: ROW_NUMBER + COUNT() OVER = median trick
-- Key lesson: compute rank AND partition size as two windows on the
--             same rows. Median rows satisfy:
--             rn BETWEEN cnt/2.0 AND cnt/2.0 + 1
--             (captures 1 middle row for odd count, 2 for even).
--             /2.0 not /2 — integer division would drop even-count case.
-- =============================================================

WITH r AS (
    SELECT id,
           company,
           salary,
           ROW_NUMBER() OVER (PARTITION BY company ORDER BY salary) AS rn,
           COUNT(*)     OVER (PARTITION BY company)                 AS cnt
    FROM Employee
)
SELECT id, company, salary
FROM r
WHERE rn BETWEEN cnt / 2.0 AND cnt / 2.0 + 1;


-- =============================================================
-- PROBLEM 12 — Human Traffic of Stadium (LC 601)
-- Skill: gaps-and-islands via id − ROW_NUMBER()
-- Key lesson: within a run of consecutive ids, (id − ROW_NUMBER())
--             is constant → labels each island. Group by that label,
--             keep islands of size ≥ 3.
--             Your approach: LAG + LEAD to check neighbours directly
--             (also valid, same accepted result).
-- Accepted: 15/15 test cases
-- =============================================================

-- Your submitted solution (LAG/LEAD neighbour check):
SELECT DISTINCT id, visit_date, people
FROM (
    SELECT id,
           visit_date,
           people,
           LAG(people, 1)  OVER (ORDER BY id) AS prev1,
           LAG(people, 2)  OVER (ORDER BY id) AS prev2,
           LEAD(people, 1) OVER (ORDER BY id) AS next1,
           LEAD(people, 2) OVER (ORDER BY id) AS next2
    FROM Stadium
) AS enriched
WHERE people >= 100
  AND (
      (next1 >= 100 AND next2 >= 100)   OR   -- current is start of a run
      (prev1 >= 100 AND next1 >= 100)   OR   -- current is middle of a run
      (prev1 >= 100 AND prev2 >= 100)        -- current is end of a run
  )
ORDER BY id;

-- Classic gaps-and-islands alternative (study this pattern — it
-- appears constantly in streak/retention questions):
-- WITH q AS (
--     SELECT id, visit_date, people,
--            id - ROW_NUMBER() OVER (ORDER BY id) AS grp
--     FROM Stadium
--     WHERE people >= 100
-- )
-- SELECT id, visit_date, people
-- FROM q
-- WHERE grp IN (SELECT grp FROM q GROUP BY grp HAVING COUNT(*) >= 3)
-- ORDER BY id;


-- =============================================================
-- PROBLEM 13 — Find Cumulative Salary of an Employee (LC 579) ★ PREMIUM
-- Skill: explicit window frame ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
-- Key lesson: the only problem this week where the DEFAULT frame is wrong.
--             Default = full running total; you need a 3-row rolling sum.
--             Must spell out ROWS BETWEEN 2 PRECEDING AND CURRENT ROW.
--             Also excludes each employee's most recent month first.
-- =============================================================

SELECT id,
       month,
       SUM(salary) OVER (
           PARTITION BY id
           ORDER BY month
           ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
       ) AS Salary
FROM Employee
WHERE (id, month) NOT IN (
    SELECT id, MAX(month)
    FROM Employee
    GROUP BY id
)
ORDER BY id, month DESC;


-- =============================================================
-- PROBLEM 14 — Department Top Three Salaries (LC 185) ⭐ CAPSTONE
-- Skill: DENSE_RANK + PARTITION BY, filter rnk <= 3
-- Key lesson: DENSE_RANK is non-negotiable here.
--             "Top-three DISTINCT salaries" = three distinct salary
--             values per department. With RANK, two people tied for
--             1st push the next salary to rank 3 — you'd return the
--             wrong set. DENSE_RANK gives 1,1,2,3 so no slot is lost.
-- Accepted: 21/21 test cases
-- =============================================================

SELECT Department, Employee, Salary
FROM (
    SELECT d.name AS Department,
           e.name AS Employee,
           e.salary AS Salary,
           DENSE_RANK() OVER (
               PARTITION BY e.departmentId
               ORDER BY e.salary DESC
           ) AS rnk
    FROM Employee e
    JOIN Department d ON e.departmentId = d.id
) A
WHERE rnk <= 3;


-- =============================================================
-- PROBLEM 15 — Average Salary: Departments VS Company (LC 615) ★ PREMIUM
-- Skill: per-department avg vs company-wide avg per month + CASE
-- Key lesson: company average is a per-month aggregate stamped onto
--             each department row — computed in a separate CTE and
--             joined back. Then CASE compares the two averages.
--             Mind the month-bucketing dialect split (TO_CHAR vs DATE_FORMAT).
-- =============================================================

-- PostgreSQL
WITH m AS (
    SELECT TO_CHAR(s.pay_date, 'YYYY-MM') AS pay_month,
           e.department_id,
           s.amount
    FROM salary s
    JOIN employee e ON s.employee_id = e.employee_id
),
dept AS (
    SELECT pay_month,
           department_id,
           AVG(amount) AS dept_avg
    FROM m
    GROUP BY pay_month, department_id
),
comp AS (
    SELECT pay_month,
           AVG(amount) AS comp_avg
    FROM m
    GROUP BY pay_month
)
SELECT d.pay_month,
       d.department_id,
       CASE
           WHEN d.dept_avg > c.comp_avg THEN 'higher'
           WHEN d.dept_avg < c.comp_avg THEN 'lower'
           ELSE 'same'
       END AS comparison
FROM dept d
JOIN comp c ON d.pay_month = c.pay_month;

-- MySQL: replace TO_CHAR(s.pay_date, 'YYYY-MM') with DATE_FORMAT(s.pay_date, '%Y-%m')


-- =============================================================
-- END OF FILE
-- Commit: git add . && git commit -m "Day 4: window functions — 12/15 LeetCode accepted (ranking, LAG/LEAD, running totals, capstone)" && git push
-- Day 5 next: CTEs (recursive), EXPLAIN, indexes, query optimisation
-- =============================================================
