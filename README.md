# Sales Store Data Analysis (PostgreSQL)

A SQL portfolio project focused on cleaning retail sales data and
answering business questions using PostgreSQL.

## Project Overview

This project uses the Sales Store dataset published on Kaggle. The
workflow includes inspecting data quality, cleaning inconsistent and
missing values, and analysing product performance, customer spending,
payment preferences, purchase timing, and monthly sales trends.

-   **Tool:** PostgreSQL
-   **Language:** SQL
-   **Dataset size:** 2,005 rows and 14 columns in the supplied CSV
-   **Dataset source:** [Sales Store dataset on
    Kaggle](https://www.kaggle.com/datasets/ankitrajmishra/sales-store)

## Repository Structure

``` text
sales-store-data-analysis/
├── README.md
├── data/
│   └── sales.csv
├── sql/
│   └── sales_analysis.sql
├── screenshots/
│   └── query-results.png   # Add your own screenshot here
└── .gitignore
```

## Business Questions Answered

The SQL script explores these questions:

1.  What are the top five best-selling products by quantity among
    delivered orders?
2.  Which products are cancelled most often?
3.  Which time of day has the most purchases, and which exact hours are
    busiest?
4.  Who are the five highest-spending customers?
5.  Which product categories generate the most revenue?
6.  What are the cancellation and return rates by category?
7.  Which payment modes are used most often?
8.  How does purchasing value vary by customer age group?
9.  What is the monthly sales and quantity trend?
10. Do product-category purchase counts vary by gender?

## Data Cleaning Performed

The SQL script includes steps to:

-   Identify duplicate transaction IDs and remove extra rows.
-   Inspect column data types and missing values.
-   Remove records without a transaction ID.
-   Correct selected missing customer details using other records in the
    dataset.
-   Standardise gender, payment-mode, and order-status values.
-   Keep a raw table (`sales_store`) and perform cleaning on a working
    table (`sales`).

**Important:** Review the dataset-specific `UPDATE` statements in the
SQL script before running them. They contain assumptions about
particular customer records and should only be used if verified against
your copy of the data.

## How to Run the Project

1.  Download or clone this repository.
2.  Open PostgreSQL using pgAdmin or another PostgreSQL client.
3.  Create a database, for example `sales_analysis`.
4.  Open `sql/sales_analysis.sql` and review the data-loading command
    first.
5.  Update the `COPY` file path to a location accessible to the
    PostgreSQL server. The script currently contains a local Windows
    path from the original working environment; that path will not work
    on another computer.
6.  Confirm that the CSV columns are in the same order as the table
    definition. The supplied CSV headers contain the spellings `quantiy`
    and `prce`, while the SQL table uses `quantity` and `price`;
    PostgreSQL `COPY` maps CSV values by column position when loading a
    header row, not by matching header names.
7.  Run the table setup and load steps, then run the cleaning and
    analysis queries in order.
8.  Inspect query results and add genuine screenshots to the
    `screenshots/` folder.

The script uses PostgreSQL-specific syntax such as `FILTER`, `ctid`,
`TO_CHAR`, and `EXTRACT`.

## Key Metrics and Definitions

-   **Sales value used in the queries:** `price * quantity`
-   **Top products by quantity:** counts only rows where status is
    `delivered`
-   **Cancellation/return rate:** category-level percentage of rows
    marked `cancelled` or `returned`
-   **Purchase time analysis:** groups purchase records into Night,
    Morning, Afternoon, and Evening, and also analyses exact hours

These are the definitions used by the current SQL script. The
sales-value calculations should not automatically be interpreted as
recognised revenue or profit: confirm the treatment of cancelled,
returned, pending, and delivered transactions before using the figures
for business decisions.

## Results and Visuals

Add verified results after running the queries. Recommended screenshots:

-   Monthly sales trend
-   Revenue by product category
-   Top products by quantity
-   Cancellation and return rates by category
-   Orders by time of day

Do not add invented figures. Screenshots should show the query or chart
title and readable values.

## What I Learned

-   Writing SQL queries for business analysis
-   Identifying duplicates and missing values
-   Standardising inconsistent categorical data
-   Using `GROUP BY`, aggregate functions, `CASE`, date/time extraction,
    and conditional aggregation
-   Translating business questions into SQL queries

## Future Improvements

-   Build a Power BI dashboard using the cleaned dataset.
-   Add KPI cards for sales value, order count, quantity sold,
    cancellations, and returns.
-   Compare trends by month, product category, payment mode, and
    customer segment.
-   Validate revenue definitions and document assumptions before
    presenting final business conclusions.

## Credits

Dataset: [Sales Store ---
Kaggle](https://www.kaggle.com/datasets/ankitrajmishra/sales-store)

This is an independent learning and portfolio project. Dataset ownership
and licensing remain with the original publisher; review the Kaggle
dataset's license before redistributing the CSV publicly.
