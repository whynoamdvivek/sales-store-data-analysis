-- =====================================================================
-- SALES STORE: DATA CLEANING + BUSINESS ANALYSIS (PostgreSQL)
-- =====================================================================
-- Run this while connected to your target database (replaces USE ...).
-- =====================================================================


-- =====================================================================
-- PART 1: TABLE SETUP & DATA LOAD
-- =====================================================================

DROP TABLE IF EXISTS sales_store;

-- Column names are spelled correctly from the start (quantity, price),
-- so no rename step is needed later.
CREATE TABLE sales_store (
    transaction_id    VARCHAR(15),
    customer_id       VARCHAR(15),
    customer_name     VARCHAR(30),
    customer_age      INT,
    gender            VARCHAR(15),
    product_id        VARCHAR(15),
    product_name      VARCHAR(30),
    product_category  VARCHAR(30),
    quantity          INT,
    price             NUMERIC(12,2),
    payment_mode      VARCHAR(15),
    purchase_date     DATE,
    time_of_purchase  TIME,
    status            VARCHAR(15)
);

-- CSV dates are in day-month-year format (replaces SET DATEFORMAT dmy)
SET datestyle = 'ISO, DMY';

-- Server-side load (file must be readable by the Postgres server):
COPY sales_store
FROM '"C:\Users\Vivek Kumar\OneDrive\Desktop\Dataset\sql project\sales.csv"'
WITH (FORMAT csv, HEADER true, DELIMITER ',');



-- Working copy: keep the raw table untouched, clean the copy
DROP TABLE IF EXISTS sales;
CREATE TABLE sales AS SELECT * FROM sales_store;


-- =====================================================================
-- PART 2: DATA CLEANING
-- =====================================================================

-- ---------------------------------------------------------------------
-- Step 1: Find and remove duplicate transactions
-- ---------------------------------------------------------------------
-- Business Problem:
--   The same transaction can be loaded more than once (double imports,
--   system retries, manual re-uploads). Every duplicate row is counted
--   as a real sale.
-- Business Impact:
--   Revenue, quantity and customer-spend figures are inflated, which
--   leads to over-optimistic forecasts, wrong stock planning and
--   mistrust of reports. Removing duplicates makes every later number
--   reliable.

-- 1a. Which transaction IDs are duplicated?
SELECT transaction_id, COUNT(*) AS occurrences
FROM sales
GROUP BY transaction_id
HAVING COUNT(*) > 1;

-- 1b. Inspect the duplicate rows before deleting
SELECT *
FROM (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY transaction_id ORDER BY ctid) AS row_num
    FROM sales
) t
WHERE transaction_id IN (
    SELECT transaction_id FROM sales GROUP BY transaction_id HAVING COUNT(*) > 1
);

-- 1c. Delete extra copies, keeping the first one of each transaction
DELETE FROM sales
WHERE ctid IN (
    SELECT ctid
    FROM (
        SELECT ctid,
               ROW_NUMBER() OVER (PARTITION BY transaction_id ORDER BY ctid) AS row_num
        FROM sales
    ) t
    WHERE row_num > 1
);


-- ---------------------------------------------------------------------
-- Step 2: Check data types
-- ---------------------------------------------------------------------
-- Business Problem:
--   Numbers or dates stored as the wrong type (e.g. price as text)
--   cannot be summed, sorted or filtered correctly.
-- Business Impact:
--   Wrong data types silently break calculations such as revenue and
--   monthly trends, producing incorrect decisions.

SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'sales'
ORDER BY ordinal_position;


-- ---------------------------------------------------------------------
-- Step 3: Check and treat NULL values
-- ---------------------------------------------------------------------
-- Business Problem:
--   Missing customer, product or price details make records incomplete
--   and unusable for analysis.
-- Business Impact:
--   Nulls cause customers to be missed in loyalty analysis, revenue to
--   be understated and segment reports (age, gender) to be incomplete.

-- 3a. NULL count per column (replaces the dynamic-SQL block)
SELECT
    COUNT(*) FILTER (WHERE transaction_id   IS NULL) AS transaction_id,
    COUNT(*) FILTER (WHERE customer_id      IS NULL) AS customer_id,
    COUNT(*) FILTER (WHERE customer_name    IS NULL) AS customer_name,
    COUNT(*) FILTER (WHERE customer_age     IS NULL) AS customer_age,
    COUNT(*) FILTER (WHERE gender           IS NULL) AS gender,
    COUNT(*) FILTER (WHERE product_id       IS NULL) AS product_id,
    COUNT(*) FILTER (WHERE product_name     IS NULL) AS product_name,
    COUNT(*) FILTER (WHERE product_category IS NULL) AS product_category,
    COUNT(*) FILTER (WHERE quantity         IS NULL) AS quantity,
    COUNT(*) FILTER (WHERE price            IS NULL) AS price,
    COUNT(*) FILTER (WHERE payment_mode     IS NULL) AS payment_mode,
    COUNT(*) FILTER (WHERE purchase_date    IS NULL) AS purchase_date,
    COUNT(*) FILTER (WHERE time_of_purchase IS NULL) AS time_of_purchase,
    COUNT(*) FILTER (WHERE status           IS NULL) AS status
FROM sales;

-- 3b. View the rows that contain at least one NULL
SELECT *
FROM sales
WHERE transaction_id IS NULL OR customer_id IS NULL OR customer_name IS NULL
   OR customer_age IS NULL OR gender IS NULL OR product_id IS NULL
   OR product_name IS NULL OR product_category IS NULL OR quantity IS NULL
   OR payment_mode IS NULL OR purchase_date IS NULL OR status IS NULL
   OR price IS NULL;

-- 3c. Rows with no transaction ID cannot be traced -> delete
DELETE FROM sales WHERE transaction_id IS NULL;

-- 3d. Fix missing values using other rows of the same customer
--     (these values are specific to this dataset; verify each first)
SELECT * FROM sales WHERE customer_name = 'Ehsaan Ram';
UPDATE sales SET customer_id = 'CUST9494' WHERE transaction_id = 'TXN977900';

SELECT * FROM sales WHERE customer_name = 'Damini Raju';
UPDATE sales SET customer_id = 'CUST1401' WHERE transaction_id = 'TXN985663';

SELECT * FROM sales WHERE customer_id = 'CUST1003';
UPDATE sales
SET customer_name = 'Mahika Saini', customer_age = 35, gender = 'Male'
WHERE transaction_id = 'TXN432798';


-- ---------------------------------------------------------------------
-- Step 4: Standardise inconsistent values
-- ---------------------------------------------------------------------
-- Business Problem:
--   The same thing is written in different ways ("Male" / "M",
--   "CC" / "Credit Card", "Delivered" / "delivered"). PostgreSQL treats
--   these as different values (it is case-sensitive).
-- Business Impact:
--   One category gets split into several, so counts and percentages are
--   understated and charts show duplicate labels.

SELECT DISTINCT gender FROM sales;
UPDATE sales SET gender = 'M' WHERE gender = 'Male';
UPDATE sales SET gender = 'F' WHERE gender = 'Female';

SELECT DISTINCT payment_mode FROM sales;
UPDATE sales SET payment_mode = 'Credit Card' WHERE payment_mode = 'CC';

-- Status: trim spaces and use lowercase so filters like 'delivered' work
SELECT DISTINCT status FROM sales;
UPDATE sales SET status = LOWER(TRIM(status));


-- =====================================================================
-- PART 3: BUSINESS ANALYSIS
-- =====================================================================

-- ---------------------------------------------------------------------
-- Q1. What are the top 5 best-selling products by quantity?
-- ---------------------------------------------------------------------
-- Business Problem:
--   The business does not know which products customers want most.
--   Stock is bought and promotions are planned on guesswork, so
--   popular items run out while slow items sit in the warehouse.
-- Business Impact:
--   Knowing the top sellers lets the team keep them well stocked,
--   negotiate better supplier rates, feature them in campaigns and
--   bundle them with slower products. Only delivered orders are
--   counted so the ranking reflects real, completed sales.

SELECT product_name,
       SUM(quantity) AS total_quantity_sold
FROM sales
WHERE status = 'delivered'
GROUP BY product_name
ORDER BY total_quantity_sold DESC
LIMIT 5;


-- ---------------------------------------------------------------------
-- Q2. Which products are cancelled most often?
-- ---------------------------------------------------------------------
-- Business Problem:
--   Frequent cancellations mean customers change their mind after
--   ordering. Causes can be poor product descriptions, wrong pricing,
--   long delivery times or quality concerns.
-- Business Impact:
--   Each cancellation is lost revenue plus wasted handling and
--   logistics cost, and it erodes customer trust. Spotting the worst
--   products lets the business fix listings, improve quality, speed up
--   delivery or remove the product from the catalogue.

SELECT product_name,
       COUNT(*) AS total_cancelled
FROM sales
WHERE status = 'cancelled'
GROUP BY product_name
ORDER BY total_cancelled DESC
LIMIT 5;


-- ---------------------------------------------------------------------
-- Q3. What time of day has the most purchases?
-- ---------------------------------------------------------------------
-- Business Problem:
--   Demand is not spread evenly across the day, but staffing, ad spend
--   and server capacity are usually planned as if it were.
-- Business Impact:
--   Identifying peak hours lets the business schedule support staff
--   when customers are active, run flash sales and ads at the best
--   time, and scale servers up before rush hours to avoid crashes and
--   lost sales, while saving cost in quiet periods.

-- 3a. By part of the day
SELECT
    CASE
        WHEN EXTRACT(HOUR FROM time_of_purchase) BETWEEN 0  AND 5  THEN 'Night'
        WHEN EXTRACT(HOUR FROM time_of_purchase) BETWEEN 6  AND 11 THEN 'Morning'
        WHEN EXTRACT(HOUR FROM time_of_purchase) BETWEEN 12 AND 17 THEN 'Afternoon'
        ELSE 'Evening'
    END AS time_of_day,
    COUNT(*) AS total_orders
FROM sales
GROUP BY time_of_day
ORDER BY total_orders DESC;

-- 3b. By exact hour
SELECT EXTRACT(HOUR FROM time_of_purchase)::INT AS hour_of_day,
       COUNT(*) AS total_orders
FROM sales
GROUP BY hour_of_day
ORDER BY hour_of_day;


-- ---------------------------------------------------------------------
-- Q4. Who are the top 5 highest-spending customers?
-- ---------------------------------------------------------------------
-- Business Problem:
--   A small group of customers usually generates a large share of
--   revenue, but without identifying them they are treated like
--   everyone else and may leave unnoticed.
-- Business Impact:
--   Knowing the VIP customers allows personalised offers, early access
--   to sales, loyalty rewards and dedicated support. Retaining one
--   high-value customer is far cheaper than acquiring a new one, so
--   this directly protects revenue.

SELECT customer_name,
       '₹ ' || TO_CHAR(SUM(price * quantity), 'FM999,999,999,990') AS total_spend
FROM sales
GROUP BY customer_name
ORDER BY SUM(price * quantity) DESC
LIMIT 5;


-- ---------------------------------------------------------------------
-- Q5. Which product categories generate the most revenue?
-- ---------------------------------------------------------------------
-- Business Problem:
--   Without category-level revenue, the business cannot tell which
--   product lines drive growth and which only take up shelf space and
--   capital.
-- Business Impact:
--   Management can invest more in high-revenue categories, expand
--   their range, secure supply and shift marketing budget towards
--   them, while reviewing or reducing weak categories. This improves
--   profit and inventory efficiency.

SELECT product_category,
       '₹ ' || TO_CHAR(SUM(price * quantity), 'FM999,999,999,990') AS revenue
FROM sales
GROUP BY product_category
ORDER BY SUM(price * quantity) DESC;


-- ---------------------------------------------------------------------
-- Q6. What is the cancellation and return rate per category?
-- ---------------------------------------------------------------------
-- Business Problem:
--   Some categories may have much higher cancellations or returns,
--   which points to dissatisfaction, misleading descriptions, sizing
--   or quality problems, or delivery issues.
-- Business Impact:
--   High rates mean lost revenue, extra shipping and restocking cost,
--   and unhappy customers. Tracking them per category shows where to
--   improve product descriptions, packaging, quality checks or
--   logistics partners, and reduces losses over time.

SELECT product_category,
       ROUND(100.0 * COUNT(*) FILTER (WHERE status = 'cancelled') / COUNT(*), 2) AS cancelled_percent,
       ROUND(100.0 * COUNT(*) FILTER (WHERE status = 'returned')  / COUNT(*), 2) AS returned_percent
FROM sales
GROUP BY product_category
ORDER BY cancelled_percent DESC;


-- ---------------------------------------------------------------------
-- Q7. What is the most preferred payment mode?
-- ---------------------------------------------------------------------
-- Business Problem:
--   The business offers several payment methods, but each has a
--   different cost, failure rate and processing effort. It is unclear
--   which ones customers actually use.
-- Business Impact:
--   Knowing the favourites lets the business make popular methods fast
--   and reliable, negotiate lower gateway fees, run payment-linked
--   offers (e.g. bank cashback) and retire rarely used options.
--   Smoother checkout means fewer abandoned payments.

SELECT payment_mode,
       COUNT(*) AS total_count
FROM sales
GROUP BY payment_mode
ORDER BY total_count DESC;


-- ---------------------------------------------------------------------
-- Q8. How does age group affect purchasing behaviour?
-- ---------------------------------------------------------------------
-- Business Problem:
--   Customers of different ages buy different things and spend
--   different amounts, but campaigns are often generic for everyone.
-- Business Impact:
--   Understanding spend by age group allows targeted marketing,
--   age-appropriate product recommendations, the right choice of
--   channels (social media vs email) and better use of ad budget,
--   improving conversion and return on marketing spend.

SELECT
    CASE
        WHEN customer_age BETWEEN 18 AND 25 THEN '18-25'
        WHEN customer_age BETWEEN 26 AND 35 THEN '26-35'
        WHEN customer_age BETWEEN 36 AND 50 THEN '36-50'
        ELSE '51+'
    END AS age_group,
    '₹ ' || TO_CHAR(SUM(price * quantity), 'FM999,999,999,990') AS total_purchase
FROM sales
GROUP BY age_group
ORDER BY SUM(price * quantity) DESC;


-- ---------------------------------------------------------------------
-- Q9. What is the monthly sales trend?
-- ---------------------------------------------------------------------
-- Business Problem:
--   Sales rise and fall through the year (festivals, seasons,
--   campaigns), but without a month-by-month view these swings go
--   unnoticed until stock is already short or in excess.
-- Business Impact:
--   Seeing the trend helps plan inventory ahead of peak months, time
--   promotions for slow months, set realistic sales targets, and
--   measure whether a campaign actually lifted sales.

SELECT TO_CHAR(purchase_date, 'YYYY-MM') AS month_year,
       SUM(price * quantity)             AS total_sales,
       SUM(quantity)                     AS total_quantity
FROM sales
GROUP BY month_year
ORDER BY month_year;


-- ---------------------------------------------------------------------
-- Q10. Do genders prefer different product categories?
-- ---------------------------------------------------------------------
-- Business Problem:
--   Product preferences may differ by gender, but if the business
--   advertises every category to everyone, ad spend is wasted and
--   messages feel irrelevant.
-- Business Impact:
--   Knowing which categories each gender buys most enables
--   personalised ads, tailored homepage and email content, and
--   focused campaigns, raising click-through and conversion rates
--   while lowering cost per sale.

-- 10a. Long format
SELECT gender,
       product_category,
       COUNT(*) AS total_purchase
FROM sales
GROUP BY gender, product_category
ORDER BY gender, total_purchase DESC;

-- 10b. Pivot format (gender was standardised to 'M' / 'F' in cleaning)
SELECT product_category,
       COUNT(*) FILTER (WHERE gender = 'M') AS male,
       COUNT(*) FILTER (WHERE gender = 'F') AS female
FROM sales
GROUP BY product_category
ORDER BY product_category;
