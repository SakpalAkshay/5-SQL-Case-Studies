WITH cte AS (
    SELECT 
        *,
        RANK() OVER (PARTITION BY employee_id ORDER BY change_date DESC) AS rn_latest_salary,
        LAG(salary, 1) OVER (PARTITION BY employee_id ORDER BY change_date) AS sal_prev
    FROM Salary_History
),

latest_salary AS (
    SELECT * 
    FROM cte 
    WHERE rn_latest_salary = 1
),

-- Task 2 - Total Number of Promotions for Each Employee
promotions_got AS (
    SELECT 
        employee_id, 
        COUNT(*) AS No_of_Promotions 
    FROM cte 
    WHERE promotion = 'Yes' 
    GROUP BY employee_id
),

-- Task 3 - Salary Hike Percentage
salary_hike_percent AS (
    SELECT 
        *, 
        ROUND(
            (salary - LAG(salary, 1) OVER (PARTITION BY employee_id ORDER BY change_date)) * 100.0 / salary,
            2
        ) AS Percent_Diff
    FROM cte
),

max_hike AS (
    SELECT 
        employee_id, 
        MAX(Percent_Diff) AS max_perecent_hike 
    FROM salary_hike_percent 
    GROUP BY employee_id
),

-- Task 4 - Salary which reduced in time
decreased_salary AS (
    SELECT DISTINCT 
        employee_id, 
        'N' AS Never_decreased  
    FROM salary_hike_percent 
    WHERE salary < sal_prev
),

diff_between_dates AS (
    SELECT 
        *, 
        DATEDIFF(
            month,
            LAG(change_date, 1) OVER (PARTITION BY employee_id ORDER BY change_date),
            change_date
        ) AS months_btw_change 
    FROM cte
),

Avg_Months_Change AS (
    SELECT 
        employee_id, 
        AVG(months_btw_change) AS Avg_months_for_change 
    FROM diff_between_dates 
    GROUP BY employee_id
)

-- Final Output
SELECT 
    ls.employee_id, 
    emp.name, 
    ls.salary AS latest_salary, 
    ISNULL(pg.No_of_Promotions, 0) AS number_of_promotions, 
    mh.max_perecent_hike AS max_percent_hike,
    ISNULL(ds.Never_decreased, 'Y') AS Never_Decreased, 
    amc.Avg_months_for_change AS Avg_Months_For_Salary_Change
FROM latest_salary ls 
LEFT JOIN Employees emp ON ls.employee_id = emp.employee_id
LEFT JOIN promotions_got pg ON ls.employee_id = pg.employee_id
LEFT JOIN max_hike mh ON ls.employee_id = mh.employee_id
LEFT JOIN decreased_salary ds ON ls.employee_id = ds.employee_id
LEFT JOIN Avg_Months_Change amc ON ls.employee_id = amc.employee_id;
