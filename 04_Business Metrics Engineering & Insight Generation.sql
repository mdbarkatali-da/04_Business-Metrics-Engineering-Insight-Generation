use interview_db


select * from dbo.[03_Details]
select * from dbo.[03_Orders]

-- ==========================  JOIN  ==================================
-- 1. List all customers who ordered products in the 'Electronics' category and their total spending.

select
	o.CustomerName,
	sum(cast(d.Amount as int)*d.Quantity) as 'total_spend'
from [03_Orders] as o
join [03_Details] as d on o.Order_ID=d.Order_ID
where
	d.Category='Electronics'
group by
	o.CustomerName

-- 2. Get a list of customers who placed more than 3 orders in different months.

WITH CTE AS(
SELECT
	FORMAT(O.Order_Date,'yyyy-MM') AS MONTH,
	O.CustomerName
FROM
	[03_Orders] AS O JOIN [03_Details] AS D ON O.Order_ID=D.Order_ID
GROUP BY
	FORMAT(O.Order_Date,'yyyy-MM'),O.CustomerName
)
SELECT
	CUSTOMERNAME,
	COUNT(MONTH) AS MONTH_COUNT
FROM
	CTE
GROUP BY CUSTOMERNAME
HAVING COUNT(MONTH)>3


-- 3. For each product, list its total revenue and the number of customers who bought it.

SELECT
	D.Sub_Category AS PRODUCT,
	SUM(CAST(D.Amount AS int)*D.Quantity) AS TOTAL_REVENUE,
	COUNT(O.CustomerName) AS TOTAL_CUSTOMERS
FROM [03_Details] AS D JOIN [03_Orders] AS O ON D.Order_ID=O.Order_ID
GROUP BY
	D.Sub_Category


-- ==================  Subqueries  ================================================
-- 1. Find customers who have spent more than the average customer spend.

WITH CTE AS(
SELECT
	 O.CustomerName,
	SUM(CAST(D.Amount AS INT)*D.Quantity)  AS TOTAL_SPEND
FROM
	[03_Orders] AS O JOIN [03_Details] AS D ON O.Order_ID=D.Order_ID
GROUP BY
	O.CustomerName
)
SELECT
	*
FROM
	CTE
WHERE 
	TOTAL_SPEND>(SELECT AVG(TOTAL_SPEND) FROM CTE)
ORDER BY
	TOTAL_SPEND



-- 2. List products that have never been ordered.

-- 3. Identify the most frequently purchased product per customer.


WITH CTE AS(
SELECT
	O.CustomerName,
	D.Sub_Category AS PRODUCT,
	COUNT(D.Sub_Category) AS ORDER_PRODUCT
FROM
	[03_Orders] AS O JOIN [03_Details] AS D ON O.Order_ID=D.Order_ID
GROUP BY
	O.CustomerName,
	D.Sub_Category
), 
CTE2 AS (
SELECT
	CUSTOMERNAME,
	PRODUCT,
	ORDER_PRODUCT,
	DENSE_RANK() OVER (PARTITION BY CUSTOMERNAME ORDER BY ORDER_PRODUCT DESC) AS ORDER_RANK
FROM 
	CTE
)
SELECT * FROM CTE2 WHERE CTE2.ORDER_RANK=1


-- =======================  Views  ==================================================
-- 1. Create a view that shows customer name, total number of orders, and total spending.

CREATE VIEW CUST_SPEND_AND_ORDERS AS
SELECT 
	O.CustomerName,
	COUNT(D.Order_ID) AS TOTAL_NUMBERS_OF_ORDERS,
	SUM(CAST(D.Amount AS INT)*D.Quantity) AS TOTAL_SPEND
FROM
	[03_Details] AS D JOIN [03_Orders] AS O ON O.Order_ID=D.Order_ID
GROUP BY
	O.CustomerName

SELECT * FROM CUST_SPEND_AND_ORDERS		--SEE VIEW



-- 2. Create an updatable view that returns orders from the last 30 days.

CREATE VIEW  LAST_30_DAYS_SALE AS 
SELECT
	O.CustomerName,
	O.Order_ID,
	O.Order_Date,
	O.State,
	O.City,
	D.Category,
	D.Sub_Category,
	D.Amount,
	D.Quantity,
	D.PaymentMode,
	D.Profit
FROM
	[03_Details] AS D JOIN [03_Orders] AS O ON D.Order_ID=O.Order_ID
WHERE
	O.Order_Date>=DATEADD(DAY,-30,GETDATE())


SELECT * FROM LAST_30_DAYS_SALE ORDER BY Order_Date DESC


--3. Create a view showing monthly sales per category and use it in a follow-up query to get YoY growth.

CREATE VIEW MONTHLY_SALE AS 
SELECT
	YEAR(O.Order_Date) AS YEAR,
	MONTH(O.Order_Date) AS MONTH,
	D.Category,
	SUM(CAST(D.Amount AS int)*D.Quantity) AS MONTHLY_SALE
FROM
	[03_Details] AS D JOIN [03_Orders] AS O ON D.Order_ID=O.Order_ID
GROUP BY
	YEAR(O.Order_Date),
	MONTH(O.Order_Date),
	D.Category

-----===========PERCENTAGE OF YEARLY_SALE  ========================

WITH CTE AS (
SELECT
	M.YEAR AS YEAR,
	SUM(M.MONTHLY_SALE) AS YEAR_SALE
FROM
	MONTHLY_SALE AS M
GROUP  BY
	YEAR
)
SELECT
	YEAR,
	YEAR_SALE*100.0/SUM(YEAR_SALE) OVER() AS PERCENTAGE_OF_SHARE
FROM
	CTE 


-----------==============  YEARLY GROWTH  =========================
WITH CTE AS (
SELECT
	M.YEAR,
	SUM(M.MONTHLY_SALE) AS CURR_YEAR_SALE,
	LAG(SUM(M.MONTHLY_SALE)) OVER(ORDER BY YEAR) AS PRE_YEAR_SALE
FROM
	MONTHLY_SALE AS M
GROUP BY
	M.YEAR
)
SELECT
	*,
	(CURR_YEAR_SALE-PRE_YEAR_SALE)*100.0/PRE_YEAR_SALE AS YOY_GROWTH
FROM
	CTE


--========================	Stored Procedures	=================================

--1. Write a stored procedure that accepts @StartDate and @EndDate and returns total sales by category.

--create 
alter proc s_date_and_e_date
@startdate date,
@enddate date
as
	begin
select
	*
from
	dbo.[03_Details] as d join dbo.[03_Orders] as o on d.Order_ID=o.Order_ID
where
	o.Order_Date between @startdate and @enddate
order by 
	o.Order_Date
	end


select * from [03_Orders]

exec s_date_and_e_date '2025-09-1' , '2025-10-30' 

-- 2. Create a stored procedure that updates customer email if it exists; otherwise inserts a new customer.

-- 3. Write a stored procedure to archive orders older than 1 year into a separate table.

create proc older_than_1_year
as
	begin
		select	
			*  into one_year_old_data
		from
			[03_Orders] as o join dbo.[03_Details] as d on o.Order_ID=d.Order_ID
		where
			o.Order_Date<=DATEADD(year,-1,getdate())
		order by
			o.Order_Date desc
	end


exec older_than_1_year 
select * from one_year_old_data


---=======================CTE (Comman Table Expression)	=========================

-- 1. Use a CTE to find customers who placed orders in 3 consecutive months.

with consecutive_month as
(select
	o.CustomerName,
	format(o.Order_Date,'yyyy_MM') as year_month,
	o.Order_ID
from
	[03_Orders] as o
group by
	o.Order_ID,
	format(o.Order_Date,'yyyy_MM'),
	o.CustomerName
),
order_month as(
select
	*,
	ROW_NUMBER() over(partition by customername order by year_month ) as number
from
	consecutive_month
)
select
distinct customername
from
	order_month
where number>3

--2. Create a recursive CTE to display a product category hierarchy (if applicable)

--3. With a CTE, show top 3 customers by monthly spending for each month.

with top_3_customers as
(select
	format(o.Order_Date,'yyyy-MM') as year_month,
	o.CustomerName,
	sum(d.Amount) as total_spend
from
	dbo.[03_Details] as d join dbo.[03_Orders] as o
	on d.Order_ID=o.Order_ID
group by
	format(o.Order_Date,'yyyy-MM'),
	o.CustomerName
),
top_3 as (select
	*,
	DENSE_RANK() over(partition by year_month order by total_spend desc) as ranking
from 
	top_3_customers)
select
	*
from
	top_3
where ranking<=3


--						Window Functions

--1. For each order, calculate running total of customer spend.
with customer_spend as
(select
	o.CustomerName,
	o.Order_ID,
	sum(d.Amount) as amount
from
	dbo.[03_Details] as d join dbo.[03_Orders] as o
	on d.Order_ID=o.Order_ID
group by
	o.CustomerName,
	o.Order_ID
)
select
	*,
	SUM(amount) over(order by order_id) as running_total
from
	customer_spend


--2. Rank products within each category by total sales using RANK() or DENSE_RANK().

with ranking_product as
(select
	d.Category,
	d.Sub_Category as products,
	sum(d.Amount) as total_sales
from
	dbo.[03_Details] as d 
group by
	d.Category,
	d.Sub_Category
)
select
	*,
	DENSE_RANK() over (partition by category order by total_sales desc) as rank
from
	ranking_product

--3. Find the previous and next order date for each customer using LAG() and LEAD().

select
	o.CustomerName,
	o.Order_Date,
	LAG(o.order_date) over (partition by o.customername order by order_date) as previous,
	LEAD(o.order_date) over (partition  by o.customername order by order_date) as next
from
	dbo.[03_Orders] as o
