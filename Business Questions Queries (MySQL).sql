USE carrefour_db;

-- ✨ First: Sales & Profit Performance. ✨

-- Q1) What are the total Sales and net profit on a monthly and Year basis?
SELECT 
	D.year,
    IFNULL(CAST(D.month AS CHAR), 'Total Year Sales') AS month,
    FORMAT(SUM(O.value), 0) AS Total_Sales,
    FORMAT(SUM(O.profit), 0) AS Total_Profit,
    CONCAT(FORMAT((SUM(O.profit) / SUM(O.value)) * 100, 2), '%') AS Profit_Margin
    
FROM 
	fact_orders O
 JOIN 
	dim_date D ON O.order_date = D.date
GROUP BY 
    D.year, 
    D.month WITH ROLLUP;

-- Q2) Which days of the week see the highest volume of orders?    
SELECT 
	D.day_name,
    FORMAT(COUNT(distinct O.order_id), 0) AS Total_Orders,
    FORMAT(SUM(O.value), 0) AS Total_Sales
    
FROM
	fact_orders O
JOIN 
	dim_date D ON O.order_date = D.date
GROUP BY 
    D.day_name
ORDER BY 
    Total_Sales DESC;

-- ********************************************************************** --
--  ✨ Second: Customer Segmentation ✨
    
-- Q3) Which cities generate the highest sales value and the greatest profit?
SELECT 
    C.city, 
    COUNT(DISTINCT O.customer_id) AS Unique_Customers,
    FORMAT(SUM(O.value), 0) AS Total_Sales, 
    FORMAT(SUM(O.profit), 0) AS Total_Profit,
	CONCAT(FORMAT((SUM(O.profit) / SUM(O.value)) * 100, 2), '%') AS Profit_Margin

FROM 
    fact_orders O
JOIN 
    dim_customer C ON O.customer_id = C.customer_id
GROUP BY 
    C.city
ORDER BY 
    Total_Sales ASC;

-- Q4) Customer segmentation based on Repeat Buyig:
-- Calculate the total number of orders per customer, 
-- categorized into segments (one-time buyer, regular customer, high-loyalty customer), 
-- along with the percentage of revenue contributed by each segment.

WITH CustomerPurchaseStats AS (
    -- Step one: Collect data for each customer.......
    SELECT 
        customer_id,
        COUNT(order_id) AS total_orders,
        SUM(value) AS total_spent,
        MIN(order_date) AS first_purchase_date,
        MAX(order_date) AS last_purchase_date
    FROM 
        fact_orders
    GROUP BY 
        customer_id
),
CustomerClassification AS (
    -- Step two: Classifying the customer based on the number of purchases......
    SELECT 
        customer_id,
        total_orders,
        total_spent,
        DATEDIFF(last_purchase_date, first_purchase_date) AS days_as_customer,
        CASE 
            WHEN total_orders = 1 THEN 'One-Time Buyer'
            WHEN total_orders BETWEEN 2 AND 4 THEN 'Regular Buyer'
            ELSE 'Loyal/Frequent Buyer'
        END AS customer_segment
    FROM 
        CustomerPurchaseStats
)
-- Step 3: Generate the final report.....
SELECT 
    customer_segment,
    COUNT(customer_id) AS number_of_customers,
    FORMAT(SUM(total_orders), 0) AS total_segment_orders,
    FORMAT(SUM(total_spent), 0) AS total_segment_Sales,
    FORMAT(ROUND(AVG(total_spent / total_orders), 2), 0) AS avg_order_value
FROM 
    CustomerClassification
GROUP BY 
    customer_segment
ORDER BY 
    total_segment_Sales DESC;


-- Q5) Calculating the average number of days between orders for repeat customers:
WITH CustomerOrders AS (
    -- Step one: Retarn the date of each order and the last order date for same customer.....
    SELECT 
        customer_id,
        order_id,
        order_date,
        LAG(order_date) OVER (PARTITION BY customer_id ORDER BY order_date) AS previous_order_date
    FROM 
        fact_orders
),
TimeBetweenOrders AS (
    -- Step 2: Calculate the time difference in days between the current order and the previous one......
    SELECT 
        customer_id,
        DATEDIFF(order_date, previous_order_date) AS days_between_orders
    FROM 
        CustomerOrders
    WHERE 
        previous_order_date IS NOT NULL
)

-- Step 3: Merge the data with the customer table......
SELECT 
    c.city,
    COUNT(DISTINCT t.customer_id) AS repeat_customers_count,
    ROUND(AVG(t.days_between_orders), 0) AS avg_days_to_return
FROM 
    TimeBetweenOrders T
JOIN 
    dim_customer C ON T.customer_id = C.customer_id
GROUP BY 
    C.city
ORDER BY 
    avg_days_to_return ASC;


-- Q6) Who are the top 10 clients (VIP)?
SELECT 
    C.customer_id, 
    C.city,
    C.gender,
    FORMAT(SUM(O.value), 0) AS Total_Sales, 
    COUNT(O.order_id) AS Total_Orders
    
FROM 
	fact_orders O
JOIN 
    dim_customer C ON O.customer_id = C.customer_id
GROUP BY 
    C.customer_id, 
    C.city, 
    C.gender
ORDER BY 
    Total_Sales DESC
LIMIT 10;

-- ********************************************************************** --
-- ✨ Third: Product & Inventory Analysis ✨

-- Q7) Which departments are the best-selling and generate the highest total profit?
SELECT 
    P.category, 
    P.sub_category, 
    FORMAT(SUM(O.qty_ordered), 0) AS Sold_Quantity,
    FORMAT(SUM(O.value), 0) AS Total_Sales,
    FORMAT(SUM(O.gross_profit), 0) AS Total_profit,
	CONCAT(FORMAT((SUM(O.profit) / SUM(O.value)) * 100, 2), '%') AS Profit_Margin

FROM 
    fact_orders O
JOIN 
    dim_product P ON O.product_id = P.product_id
GROUP BY 
    P.category, 
    P.sub_category
ORDER BY 
    Profit_Margin DESC;

-- Q8) Which products are generating losses (their profit is negative)?
SELECT 
    P.product_id,
    P.product_name, 
    P.category,
    SUM(O.value) AS Total_Sales,
    SUM(O.expenses) AS total_expenses,
    SUM(O.profit) AS total_profit
    
FROM 
    fact_orders O
JOIN 
    dim_product P ON O.product_id = P.product_id
GROUP BY 
    P.product_id, 
    P.product_name, 
    P.category
HAVING 
    total_profit < 0
    
ORDER BY 
    total_profit ASC;

-- ********************************************************************** --
-- ✨ Fourth: Operational Efficiency ✨

-- Q9) What are the most commonly used payment methods?
SELECT 
    IFNULL(O.payment_method, 'The Total') AS Payment_method, 
    FORMAT(COUNT(O.order_id), 0) AS Total_Orders,
    FORMAT(SUM(O.value), 0) AS Total_Sales
FROM 
    fact_orders O
GROUP BY 
    O.payment_method WITH ROLLUP
ORDER BY 
    total_orders DESC;


-- Q10) The method most frequently chosen by customers:
SELECT 
    S.shipping_mode, 
    FORMAT(COUNT(O.order_id), 0) AS number_of_orders
FROM 
    fact_orders O
JOIN 
    dim_shipping S ON O.shipping_id = S.shipping_id
GROUP BY 
    S.shipping_mode
ORDER BY 
    number_of_orders DESC;


-- Q11) Ratio of shipped orders to pending orders:
SELECT 
    O.status, 
    FORMAT(COUNT(O.order_id), 0) AS order_count,
	CONCAT(ROUND((COUNT(O.order_id) / (SELECT COUNT(*) FROM fact_orders)) * 100, 2), ' %') AS percentage_of_total
FROM 
    fact_orders O
GROUP BY 
    O.status;




