

***

# Employee Salary History Report (SQL)

## Overview
A production-style SQL project that builds a consolidated employee salary report from an `Employees` table and a `SalaryHistory` table using window functions, CTEs, and aggregations. The project then refactors to a leaner, single-CTE pattern for performance and readability.

The report computes:
- Latest salary
- Promotions count
- Maximum hike percent
- “Never decreased” flag
- Average months between changes
- Rank by total growth (tie-breaking by earliest join date)

***

## Features
- Latest salary per employee by most recent `change_date`, not by `MAX(salary)`.
- Promotions count using `Promotion = 'Yes'`.
- Maximum hike percent between consecutive changes via `LEAD()` and per-employee `MAX`.
- “Never decreased” flag detecting any downward step across history.
- Average months between changes with `DATEDIFF` and NULL-safe `AVG`.
- Rank by growth ratio (`latest/first`) with tie-break by earliest join date.

***

## Data Model

### Employees
`Employees(employee_id, name, join_date, department)`  
Used for identity and display. The `join_date` may come from the earliest `change_date`.

### SalaryHistory
`SalaryHistory(employee_id, change_date, salary, promotion)`  
The first row per employee corresponds to their join; subsequent rows capture changes and promotions.

***

## Schema Assumptions
- First salary = earliest `change_date` per employee.  
- Latest salary = latest `change_date`.  
- Latest salary may be **less than** historical max if decreases occurred.

***

## Quick Start
1. Create and populate `Employees` and `SalaryHistory` tables (or use equivalent schema).  
2. Ensure an index on `(employee_id, change_date)` for optimal window scans and joins.  
3. Run the **Long-CTE version** to explore metric shapes.  
4. Then run the **Optimized version** for production.

***

## Long-CTE Version (Concept)

Build separate CTEs for:

- **Latest salary** using rank per employee (`ORDER BY change_date DESC`).  
- **Promotions count**: filter where `Promotion = 'Yes'`.  
- **Max hike percent**: use `LEAD(salary)` and calculate  
  $$((salary - prev_salary) / prev_salary) * 100.0$$  
  then take per-employee `MAX`.  
- **Never decreased**: detect rows where `salary < prev_salary`.  
- **Average months**: use `LEAD(change_date)` and compute  
  $$AVG(DATEDIFF(MONTH, prev_change_date, change_date))$$  

Finally, `LEFT JOIN` all CTEs to `Employees` and coalesce NULLs in the final report.

***

## Optimized Version (Single Base CTE)

### Base CTE Columns
```sql
rn_desc = ROW_NUMBER() OVER (PARTITION BY employee_id ORDER BY change_date DESC)
rn_asc = ROW_NUMBER() OVER (PARTITION BY employee_id ORDER BY change_date ASC)
prev_salary = LEAD(salary) OVER (PARTITION BY employee_id ORDER BY change_date DESC)
prev_change_date = LEAD(change_date) OVER (PARTITION BY employee_id ORDER BY change_date DESC)
```

### Aggregations Per Employee
```sql
latest_salary = MAX(CASE WHEN rn_desc = 1 THEN salary END)
number_of_promotions = SUM(CASE WHEN promotion = 'Yes' THEN 1 ELSE 0 END)
max_hike_pct = MAX(((salary - prev_salary) / prev_salary) * 100.0)
never_decreased = CASE WHEN MAX(CASE WHEN salary < prev_salary THEN 1 ELSE 0 END) = 0 THEN 'Y' ELSE 'N' END
avg_months_between_changes = AVG(DATEDIFF(MONTH, prev_change_date, change_date))
```

### Growth and Rank
```sql
first_salary = MAX(CASE WHEN rn_asc = 1 THEN salary END)
latest_salary_from_rn = MAX(CASE WHEN rn_desc = 1 THEN salary END)
growth_ratio = latest_salary_from_rn * 1.0 / first_salary
join_date_proxy = MIN(change_date)
rank_by_growth = RANK() OVER (ORDER BY growth_ratio DESC, join_date_proxy ASC)
```

***

## Example SQL Snippets

### Latest Salary via Window Rank
```sql
SELECT employee_id, salary
FROM (
  SELECT employee_id, salary,
         ROW_NUMBER() OVER (PARTITION BY employee_id ORDER BY change_date DESC) AS rn
  FROM SalaryHistory
) s
WHERE rn = 1;
```

### Previous Salary and Hike Percent
```sql
SELECT employee_id, change_date, salary,
       LEAD(salary) OVER (PARTITION BY employee_id ORDER BY change_date DESC) AS previous_salary,
       ((salary - LEAD(salary) OVER (PARTITION BY employee_id ORDER BY change_date DESC))
        / LEAD(salary) OVER (PARTITION BY employee_id ORDER BY change_date DESC)) * 100.0 AS hike_pct
FROM SalaryHistory;
```

### Average Months Between Changes
```sql
AVG(DATEDIFF(MONTH, prev_change_date, change_date)) 
-- with prev_change_date from LEAD(change_date)
```
***

## Output Columns
- `employee_id`
- `name`
- `latest_salary`
- `number_of_promotions`
- `max_hike_pct`
- `never_decreased`
- `avg_months_between_changes`

***

## Validation and Caveats
- `AVG` ignores NULL — correctly excludes the first row’s missing month gap.  
- Do not use `MIN/MAX(salary)` to infer first/latest; always use `change_date` order.  
- If partial month logic is needed, adjust `DATEDIFF` accordingly.

***

## Performance Tips
- Add index:  
  ```sql
  CREATE INDEX ix_salaryhistory_emp_date 
  ON SalaryHistory(employee_id, change_date) INCLUDE (salary, promotion);
  ```
- Use a **single base CTE** plus one outer ranking step to simplify queries and help the optimizer.

***

## Project Structure
```
/long_cte_report.sql        # Verbose multi-CTE build and final join
/optimized_report.sql       # Single-CTE aggregated version with ranking
/sample_seed.sql           # Minimal Employees and SalaryHistory seed
```

***

## License
MIT 

***
