-- Day 3: SQL Aggregation & Subqueries
-- Problems solved: 511, 586, 596, 619, 1075

-- 511. Game Play Analysis I
-- Skill: GROUP BY + MIN
-- First login date per player
select player_id, min(event_date) as first_login 
from Activity 
group by player_id;

-- 586. Customer Placing the Largest Number of Orders
-- Skill: GROUP BY + ORDER BY + LIMIT
-- Customer with most orders
select customer_number 
from Orders 
group by customer_number 
order by count(order_number) desc 
limit 1;

-- 596. Classes With at Least 5 Students
-- Skill: HAVING
-- Classes with >= 5 students
select class 
from Courses 
group by class 
having count(student) >= 5;

-- 619. Biggest Single Number
-- Skill: HAVING + derived table + MAX handles NULL automatically
-- Largest number appearing exactly once
select MAX(num) as num 
from (
    select num 
    from MyNumbers 
    group by num 
    having count(num) < 2
) t;

-- 1075. Project Employees I
-- Skill: JOIN + AVG + ROUND
-- Average experience years per project
select p.project_id, ROUND(AVG(e.experience_years), 2) as average_years 
from Project p 
left join Employee e on p.employee_id = e.employee_id 
group by p.project_id 
order by project_id;
