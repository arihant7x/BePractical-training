-- =============================================================================
-- STUDENT GRADED PORTFOLIO LAB: 20 ADVANCED SQL INTERVIEW PROBLEMS
-- DATABASE: enterprise_retail_db
-- INSTRUCTIONS: Write optimal SQL queries for each task. Push to GitHub as .sql
-- =============================================================================

USE enterprise_retail_db;

-- -----------------------------------------------------------------------------
-- PART A: JOINS, ADVANCED FILTERING & SUBQUERIES (Q1 - Q5)
-- -----------------------------------------------------------------------------

-- [Q1] Find all customers from 'USA' who placed completed orders in Q1 2024 (Jan–Mar).
--      Return customer_name, order_id, order_date, and order net revenue.
-- YOUR QUERY HERE:
SELECT
    c.customer_name,
    o.order_id,
    o.order_date,
    ROUND(SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct)), 2) AS order_net_revenue
FROM customers c
JOIN orders o
    ON c.customer_id = o.customer_id
JOIN order_items oi
    ON o.order_id = oi.order_id
WHERE c.country = 'USA'
  AND o.order_status = 'Completed'
  AND o.order_date BETWEEN '2024-01-01' AND '2024-03-31'
GROUP BY c.customer_name, o.order_id, o.order_date
ORDER BY o.order_date;



-- [Q2] Identify all sales reps (department_id = 2) who have NEVER closed an order.
--      Use an Anti-Join pattern (LEFT JOIN + IS NULL or NOT EXISTS).
-- YOUR QUERY HERE:

SELECT
    e.employee_id,
    e.first_name,
    e.last_name
FROM employees e
LEFT JOIN orders o
    ON e.employee_id = o.sales_rep_id
WHERE e.department_id = 2
  AND o.order_id IS NULL;



-- [Q3] List all products that have never been ordered in the entire history of the company.
-- YOUR QUERY HERE:
SELECT
    p.product_id,
    p.product_name
FROM products p
LEFT JOIN order_items oi
    ON p.product_id = oi.product_id
WHERE oi.product_id IS NULL;


-- [Q4] Find all employees whose salary is strictly higher than the average salary of their department.
--      Display employee name, department name, salary, and the department average salary.
-- YOUR QUERY HERE:

SELECT
    e.first_name,
    e.last_name,
    d.department_name,
    e.salary,
    dept_avg.avg_salary
FROM employees e
JOIN departments d
    ON e.department_id = d.department_id
JOIN (
    SELECT
        department_id,
        AVG(salary) AS avg_salary
    FROM employees
    GROUP BY department_id
) dept_avg
    ON e.department_id = dept_avg.department_id
WHERE e.salary > dept_avg.avg_salary
ORDER BY e.salary DESC;



-- [Q5] Find all customer segments where the total net revenue exceeds $30,000 across completed orders.
--      Display segment, total orders count, and net revenue sorted descending.
-- YOUR QUERY HERE:

SELECT
    c.segment,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct)), 2) AS net_revenue
FROM customers c
JOIN orders o
    ON c.customer_id = o.customer_id
JOIN order_items oi
    ON o.order_id = oi.order_id
WHERE o.order_status = 'Completed'
GROUP BY c.segment
HAVING SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct)) > 30000
ORDER BY net_revenue DESC;


-- -----------------------------------------------------------------------------
-- PART B: COMMON TABLE EXPRESSIONS (CTEs) & COMPLEX LOGIC (Q6 - Q8)
-- -----------------------------------------------------------------------------

-- [Q6] Using a CTE, calculate the Total Spend per customer. In the main query,
--      classify customers into 'High Spender' (>= $20k), 'Mid Spender' ($5k-$20k),
--      and 'Low Spender' (< $5k). Count the number of customers in each bracket.
-- YOUR QUERY HERE:
WITH CustomerSpend AS (
    SELECT
        c.customer_id,
        c.customer_name,
        COALESCE(
            SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct)),
            0
        ) AS total_spend
    FROM customers c
    LEFT JOIN orders o
        ON c.customer_id = o.customer_id
       AND o.order_status = 'Completed'
    LEFT JOIN order_items oi
        ON o.order_id = oi.order_id
    GROUP BY c.customer_id, c.customer_name
)
SELECT
    CASE
        WHEN total_spend >= 20000 THEN 'High Spender'
        WHEN total_spend >= 5000 THEN 'Mid Spender'
        ELSE 'Low Spender'
    END AS spender_category,
    COUNT(*) AS customer_count
FROM CustomerSpend
GROUP BY spender_category
ORDER BY customer_count DESC;


-- [Q7] Find customers who placed more than one completed order. Return customer_id,
--      customer_name, first order date, and most recent order date.
-- YOUR QUERY HERE:
WITH CustomerOrders AS (
    SELECT
        c.customer_id,
        c.customer_name,
        COUNT(o.order_id) AS completed_orders,
        MIN(o.order_date) AS first_order_date,
        MAX(o.order_date) AS most_recent_order_date
    FROM customers c
    JOIN orders o
        ON c.customer_id = o.customer_id
    WHERE o.order_status = 'Completed'
    GROUP BY c.customer_id, c.customer_name
)
SELECT
    customer_id,
    customer_name,
    first_order_date,
    most_recent_order_date
FROM CustomerOrders
WHERE completed_orders > 1
ORDER BY customer_id;



-- [Q8] Using a RECURSIVE CTE, generate a date series from '2024-01-01' to '2024-01-10'
--      and count how many orders were placed on each calendar day (including 0-order days).
-- YOUR QUERY HERE:
WITH RECURSIVE DateSeries AS (
    SELECT DATE('2024-01-01') AS calendar_date

    UNION ALL

    SELECT DATE_ADD(calendar_date, INTERVAL 1 DAY)
    FROM DateSeries
    WHERE calendar_date < '2024-01-10'
)
SELECT
    ds.calendar_date,
    COUNT(o.order_id) AS orders_placed
FROM DateSeries ds
LEFT JOIN orders o
    ON DATE(o.order_date) = ds.calendar_date
GROUP BY ds.calendar_date
ORDER BY ds.calendar_date;



-- -----------------------------------------------------------------------------
-- PART C: RANKING WINDOW FUNCTIONS (Q9 - Q12)
-- -----------------------------------------------------------------------------

-- [Q9] Find the highest paid employee in EACH department without using GROUP BY or subquery filters.
--      Use DENSE_RANK() or ROW_NUMBER() in a CTE.
-- YOUR QUERY HERE:
WITH RankedEmployees AS (
    SELECT
        e.employee_id,
        e.first_name,
        e.last_name,
        d.department_name,
        e.salary,
        DENSE_RANK() OVER (
            PARTITION BY e.department_id
            ORDER BY e.salary DESC
        ) AS salary_rank
    FROM employees e
    JOIN departments d
        ON e.department_id = d.department_id
)
SELECT
    employee_id,
    first_name,
    last_name,
    department_name,
    salary
FROM RankedEmployees
WHERE salary_rank = 1
ORDER BY department_name;



-- [Q10] (Deduplication Simulation) If duplicate orders existed, how would you pick only
--       the earliest order per customer? Write a query using ROW_NUMBER() partitioned
--       by customer_id ordered by order_date ASC.
-- YOUR QUERY HERE:
WITH RankedOrders AS (
    SELECT
        order_id,
        customer_id,
        order_date,
        ROW_NUMBER() OVER (
            PARTITION BY customer_id
            ORDER BY order_date ASC
        ) AS rn
    FROM orders
)
SELECT
    order_id,
    customer_id,
    order_date
FROM RankedOrders
WHERE rn = 1
ORDER BY customer_id;




-- [Q11] Divide all products into 4 equal price quartiles using NTILE(4) based on unit_price.
--       Display product_name, unit_price, and price_quartile (1 = lowest, 4 = highest).
-- YOUR QUERY HERE:

SELECT
    product_name,
    unit_price,
    NTILE(4) OVER (
        ORDER BY unit_price
    ) AS price_quartile
FROM products
ORDER BY unit_price;


-- [Q12] Rank all products by unit_price within their category using both RANK() and DENSE_RANK()
--       to demonstrate how ties are treated.
-- YOUR QUERY HERE:

SELECT
    c.category_name,
    p.product_name,
    p.unit_price,
    RANK() OVER (
        PARTITION BY p.category_id
        ORDER BY p.unit_price DESC
    ) AS product_rank,
    DENSE_RANK() OVER (
        PARTITION BY p.category_id
        ORDER BY p.unit_price DESC
    ) AS product_dense_rank
FROM products p
JOIN categories c
    ON p.category_id = c.category_id
ORDER BY c.category_name, p.unit_price DESC;


-- -----------------------------------------------------------------------------
-- PART D: OFFSET FUNCTIONS: LAG & LEAD (Q13 - Q15)
-- -----------------------------------------------------------------------------

-- [Q13] (Month-over-Month Growth) Calculate the total net revenue for each calendar month,
--       and use LAG() to compute the previous month's revenue and the MoM Dollar Growth.
-- YOUR QUERY HERE:

WITH MonthlyRevenue AS (
    SELECT
        DATE_FORMAT(o.order_date, '%Y-%m') AS revenue_month,
        ROUND(SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct)), 2) AS monthly_revenue
    FROM orders o
    JOIN order_items oi
        ON o.order_id = oi.order_id
    WHERE o.order_status = 'Completed'
    GROUP BY DATE_FORMAT(o.order_date, '%Y-%m')
)
SELECT
    revenue_month,
    monthly_revenue,
    LAG(monthly_revenue) OVER (ORDER BY revenue_month) AS previous_month_revenue,
    monthly_revenue -
        LAG(monthly_revenue) OVER (ORDER BY revenue_month) AS mom_dollar_growth
FROM MonthlyRevenue
ORDER BY revenue_month;


-- -----------------------------------------------------------------------------

-- [Q14] (Customer Inactivity Interval) For each customer, list all their orders in chronological
--       order and use LAG() to calculate the days elapsed since their previous order.
-- YOUR QUERY HERE:

SELECT
    customer_id,
    order_id,
    order_date,
    LAG(order_date) OVER (
        PARTITION BY customer_id
        ORDER BY order_date
    ) AS previous_order_date,
    DATEDIFF(
        order_date,
        LAG(order_date) OVER (
            PARTITION BY customer_id
            ORDER BY order_date
        )
    ) AS days_since_previous_order
FROM orders
ORDER BY customer_id, order_date;


-- -----------------------------------------------------------------------------

-- [Q15] For each order, display the current order's date, customer_id, and use LEAD()
--       to show the date of that customer's next upcoming order.
-- YOUR QUERY HERE:

SELECT
    order_id,
    customer_id,
    order_date,
    LEAD(order_date) OVER (
        PARTITION BY customer_id
        ORDER BY order_date
    ) AS next_order_date
FROM orders
ORDER BY customer_id, order_date;



-- -----------------------------------------------------------------------------
-- PART E: AGGREGATE WINDOW FUNCTIONS & FRAMES (Q16 - Q20)
-- -----------------------------------------------------------------------------

-- [Q16] (Running Total) Calculate a running cumulative total of net revenue ordered chronologically
--       by order_date across all completed orders.
-- YOUR QUERY HERE:

WITH OrderRevenue AS (
    SELECT
        o.order_id,
        o.order_date,
        ROUND(SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct)), 2) AS net_revenue
    FROM orders o
    JOIN order_items oi
        ON o.order_id = oi.order_id
    WHERE o.order_status = 'Completed'
    GROUP BY o.order_id, o.order_date
)
SELECT
    order_id,
    order_date,
    net_revenue,
    SUM(net_revenue) OVER (
        ORDER BY order_date, order_id
    ) AS running_total_revenue
FROM OrderRevenue
ORDER BY order_date, order_id;


-- -----------------------------------------------------------------------------

-- [Q17] (3-Day Moving Average) For each order date, calculate the daily revenue and a 3-day
--       moving average (current day and 2 preceding days) using
--       ROWS BETWEEN 2 PRECEDING AND CURRENT ROW.
-- YOUR QUERY HERE:

WITH DailyRevenue AS (
    SELECT
        o.order_date,
        ROUND(SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct)), 2) AS daily_revenue
    FROM orders o
    JOIN order_items oi
        ON o.order_id = oi.order_id
    WHERE o.order_status = 'Completed'
    GROUP BY o.order_date
)
SELECT
    order_date,
    daily_revenue,
    ROUND(
        AVG(daily_revenue) OVER (
            ORDER BY order_date
            ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
        ),
        2
    ) AS moving_avg_3_day
FROM DailyRevenue
ORDER BY order_date;


-- -----------------------------------------------------------------------------

-- [Q18] (Percentage of Total) For each product sold in completed orders, display product_name,
--       category_name, product revenue, and calculate what percentage that product contributes
--       to its parent category's total revenue.
-- YOUR QUERY HERE:

WITH ProductRevenue AS (
    SELECT
        p.product_id,
        p.product_name,
        c.category_name,
        ROUND(
            SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct)),
            2
        ) AS product_revenue
    FROM products p
    JOIN categories c
        ON p.category_id = c.category_id
    JOIN order_items oi
        ON p.product_id = oi.product_id
    JOIN orders o
        ON oi.order_id = o.order_id
    WHERE o.order_status = 'Completed'
    GROUP BY p.product_id, p.product_name, c.category_name
)
SELECT
    product_name,
    category_name,
    product_revenue,
    ROUND(
        (product_revenue * 100.0) /
        SUM(product_revenue) OVER (
            PARTITION BY category_name
        ),
        2
    ) AS pct_of_category_revenue
FROM ProductRevenue
ORDER BY category_name, product_revenue DESC;


-- -----------------------------------------------------------------------------

-- [Q19] Calculate the difference between each employee's salary and the highest salary
--       in their department using MAX() OVER (PARTITION BY ...).
-- YOUR QUERY HERE:

SELECT
    employee_id,
    first_name,
    last_name,
    department_id,
    salary,
    MAX(salary) OVER (
        PARTITION BY department_id
    ) AS highest_department_salary,
    MAX(salary) OVER (
        PARTITION BY department_id
    ) - salary AS salary_gap
FROM employees
ORDER BY department_id, salary DESC;


-- -----------------------------------------------------------------------------

-- [Q20] (Executive Retention Challenge) Identify customers who placed orders in two consecutive
--       months in 2024. Return distinct customer_id and customer_name.
-- YOUR QUERY HERE:

WITH CustomerMonths AS (
    SELECT DISTINCT
        customer_id,
        YEAR(order_date) AS order_year,
        MONTH(order_date) AS order_month
    FROM orders
    WHERE YEAR(order_date) = 2024
),
MonthSequence AS (
    SELECT
        customer_id,
        order_month,
        LAG(order_month) OVER (
            PARTITION BY customer_id
            ORDER BY order_month
        ) AS previous_month
    FROM CustomerMonths
)
SELECT DISTINCT
    c.customer_id,
    c.customer_name
FROM MonthSequence ms
JOIN customers c
    ON ms.customer_id = c.customer_id
WHERE ms.order_month = ms.previous_month + 1
ORDER BY c.customer_id;