-- =====================================================================
-- Day 3 — SQL Aggregation & Subqueries
-- Week 1 · Foundations
-- Status: 15 / 15 complete.
--
-- Problems 6-15 are the deferred Day 2 join problems, now finished with
-- GROUP BY / HAVING / subquery knowledge from Day 3.
-- Dialect: PostgreSQL (LeetCode judge accepts PG).
-- =====================================================================


-- ---------------------------------------------------------------------
-- 511. Game Play Analysis I
-- Skill: GROUP BY + MIN
-- First login date per player.
-- ---------------------------------------------------------------------
select player_id, min(event_date) as first_login
from Activity
group by player_id;


-- ---------------------------------------------------------------------
-- 586. Customer Placing the Largest Number of Orders
-- Skill: GROUP BY + ORDER BY count + LIMIT
-- Customer with the most orders.
-- ---------------------------------------------------------------------
select customer_number
from Orders
group by customer_number
order by count(order_number) desc
limit 1;


-- ---------------------------------------------------------------------
-- 596. Classes With at Least 5 Students
-- Skill: HAVING
-- NOTE: "at least 5" => >= 5  (NOT > 5 — off-by-one trap)
-- ---------------------------------------------------------------------
select class
from Courses
group by class
having count(student) >= 5;


-- ---------------------------------------------------------------------
-- 619. Biggest Single Number
-- Skill: HAVING + derived table; MAX() returns NULL on empty set for free
-- Largest number appearing exactly once (NULL if none).
-- ---------------------------------------------------------------------
select MAX(num) as num
from (
    select num
    from MyNumbers
    group by num
    having count(num) < 2
) t;


-- ---------------------------------------------------------------------
-- 1075. Project Employees I
-- Skill: JOIN + AVG + ROUND
-- Average experience years per project, rounded to 2.
-- ---------------------------------------------------------------------
select p.project_id,
       ROUND(AVG(e.experience_years), 2) as average_years
from Project p
left join Employee e on p.employee_id = e.employee_id
group by p.project_id
order by project_id;


-- ---------------------------------------------------------------------
-- 1661. Average Time of Process per Machine
-- Skill: self-join + AVG  (Day 2 #10)
-- Pair each 'start' row to its 'end' row on same machine + process.
-- a = start, b = end. ::numeric cast needed for ROUND in Postgres.
-- ---------------------------------------------------------------------
SELECT a.machine_id,
       round(AVG(b.timestamp - a.timestamp)::numeric, 3) AS processing_time
FROM Activity a
JOIN Activity b
  ON a.machine_id = b.machine_id
 AND a.process_id = b.process_id
 AND a.activity_type = 'start'
 AND b.activity_type = 'end'
GROUP BY a.machine_id;


-- ---------------------------------------------------------------------
-- 1731. The Number of Employees Which Report to Each Employee
-- Skill: self-join + COUNT/AVG  (Day 2 #11)
-- m = manager, e = report. INNER join keeps only actual managers.
-- NOTE: reference solution — replace with your submitted version if it differs.
-- ---------------------------------------------------------------------
select m.employee_id,
       m.name,
       COUNT(e.employee_id) as reports_count,
       ROUND(AVG(e.age))    as average_age
from Employees m
join Employees e on e.reports_to = m.employee_id
group by m.employee_id, m.name
order by m.employee_id;


-- ---------------------------------------------------------------------
-- 1280. Students and Examinations
-- Skill: CROSS JOIN + LEFT JOIN + COUNT(col)  (Day 2 #12)
-- Every student x every subject; 0 when never sat.
-- COUNT(e.subject_name) not COUNT(*) so no-shows read 0, not 1.
-- ---------------------------------------------------------------------
select s.student_id, s.student_name, sub.subject_name,
       COUNT(e.subject_name) as attended_exams
from Students s
cross join Subjects sub
left join Examinations e
       on e.student_id   = s.student_id
      and e.subject_name = sub.subject_name
group by s.student_id, s.student_name, sub.subject_name
order by s.student_id, sub.subject_name;


-- ---------------------------------------------------------------------
-- 570. Managers with at Least 5 Direct Reports
-- Skill: self-join + HAVING  (Day 2 #13)
-- Group by m.id AND m.name (two managers could share a name).
-- NOTE: reference solution — replace with your submitted version if it differs.
-- ---------------------------------------------------------------------
select m.name
from Employee e
join Employee m on e.managerId = m.id
group by m.id, m.name
having count(*) >= 5;


-- ---------------------------------------------------------------------
-- 1934. Confirmation Rate
-- Skill: LEFT JOIN + AVG(CASE)  (Day 2 #14)
-- LEFT JOIN keeps zero-request users; their NULL action -> ELSE 0 -> rate 0.
-- AVG of 1s and 0s IS the rate directly.
-- ---------------------------------------------------------------------
select s.user_id,
       round(avg(case when action = 'confirmed' then 1 else 0 end), 2) as confirmation_rate
from Signups s
left join Confirmations c on s.user_id = c.user_id
group by s.user_id;


-- ---------------------------------------------------------------------
-- 184. Department Highest Salary
-- Skill: JOIN + subquery per-group MAX  (Day 2 #16)
-- Row-value (departmentId, salary) IN (per-dept max) — keeps ties.
-- ---------------------------------------------------------------------
select d.name as Department, e.name as Employee, e.salary as Salary
from Employee e
left join Department d on e.departmentId = d.id
where (e.departmentId, e.salary) in (
    select departmentId, max(salary)
    from Employee
    group by departmentId
);


-- ---------------------------------------------------------------------
-- 1158. Market Analysis I
-- Skill: LEFT JOIN + filter-in-ON + COUNT  (Day 2 #17)
-- THE ON-vs-WHERE TRAP: year filter goes in ON, not WHERE.
-- In WHERE, NULL = 2019 -> UNKNOWN -> zero-order users dropped.
-- In ON, LEFT JOIN keeps them; COUNT(order_id) reads their NULL as 0.
-- Items table is a red herring — not joined.
-- ---------------------------------------------------------------------
SELECT u.user_id AS buyer_id,
       u.join_date,
       COUNT(o.order_id) AS orders_in_2019
FROM Users u
LEFT JOIN Orders o
       ON o.buyer_id = u.user_id
      AND EXTRACT(YEAR FROM o.order_date) = 2019
GROUP BY u.user_id, u.join_date;


-- ---------------------------------------------------------------------
-- 512. Game Play Analysis II
-- Skill: JOIN to a per-player MIN derived table  (Day 2 #19)
-- Device each player first logged in with.
-- Derived table on the LEFT, Activity on the RIGHT — avoids RIGHT JOIN.
-- ---------------------------------------------------------------------
select b.player_id, a.device_id
from (
    select player_id, min(event_date) as min_date
    from Activity
    group by player_id
) b
left join Activity a
       on a.player_id  = b.player_id
      and a.event_date = b.min_date;


-- ---------------------------------------------------------------------
-- 550. Game Play Analysis IV
-- Skill: derived table + date+1 + rate  (Day 2 #18)
-- Fraction of players who returned the day after first login.
-- COUNT(DISTINCT player) for "fraction of players"; ::numeric avoids
-- integer division (1/3 -> 0 without the cast).
-- ---------------------------------------------------------------------
SELECT ROUND(
         COUNT(DISTINCT a.player_id)::numeric
         / COUNT(DISTINCT b.player_id), 2
       ) AS fraction
FROM (
    SELECT player_id, MIN(event_date) AS start_date
    FROM Activity
    GROUP BY player_id
) b
LEFT JOIN Activity a
       ON a.player_id  = b.player_id
      AND a.event_date = b.start_date + 1;


-- ---------------------------------------------------------------------
-- 262. Trips and Users
-- Skill: double join (same table twice) + SUM(CASE) rate  (Day 2 #20)
-- Join Users twice — c = client, d = driver — both banned = 'No'.
-- One physical table, two logical roles (Trips has two FKs into Users).
-- Daily cancellation rate = cancelled / total, cancelled = status <> 'completed'.
-- ---------------------------------------------------------------------
select t.request_at as "Day",
       ROUND(SUM(case when t.status <> 'completed' then 1 ELSE 0 end)::numeric
             / COUNT(*), 2) as "Cancellation Rate"
from Trips t
join Users c on t.client_id = c.users_id and c.banned = 'No'
join Users d on t.driver_id = d.users_id and d.banned = 'No'
where t.request_at between '2013-10-01' and '2013-10-03'
group by t.request_at;