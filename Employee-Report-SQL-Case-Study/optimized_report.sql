WITH base AS (
    SELECT
        sh.employee_id,
        sh.change_date,
        sh.salary,
        sh.promotion,
        ROW_NUMBER() OVER (PARTITION BY sh.employee_id ORDER BY sh.change_date DESC) AS rn_desc,
        LAG(sh.salary)      OVER (PARTITION BY sh.employee_id ORDER BY sh.change_date) AS prev_salary,
        LAG(sh.change_date) OVER (PARTITION BY sh.employee_id ORDER BY sh.change_date) AS prev_change_date
    FROM Salary_History sh
),
agg AS (
    SELECT
        b.employee_id,
        -- Latest salary by most recent change_date
        MAX(CASE WHEN b.rn_desc = 1 THEN b.salary END) AS latest_salary,

        -- Promotions count
        SUM(CASE WHEN b.promotion = 'Yes' THEN 1 ELSE 0 END) AS number_of_promotions,

        -- Max hike percent between consecutive changes; guard against divide-by-zero
        MAX(
            ROUND(
                (b.salary - b.prev_salary) * 100.0 / NULLIF(b.prev_salary, 0),
                2
            )
        ) AS max_percent_hike,

        -- Never decreased flag
        CASE WHEN MAX(CASE WHEN b.salary < b.prev_salary THEN 1 ELSE 0 END) = 0
             THEN 'Y' ELSE 'N' END AS Never_Decreased,

        -- Average months between changes (AVG ignores NULL first gap)
        AVG(CAST(DATEDIFF(month, b.prev_change_date, b.change_date) AS float)) AS Avg_Months_For_Salary_Change
    FROM base b
    GROUP BY b.employee_id
)
SELECT
    a.employee_id,
    e.name,
    a.latest_salary,
    a.number_of_promotions,
    a.max_percent_hike,
    a.Never_Decreased,
    a.Avg_Months_For_Salary_Change
FROM agg a
LEFT JOIN Employees e
  ON a.employee_id = e.employee_id;
