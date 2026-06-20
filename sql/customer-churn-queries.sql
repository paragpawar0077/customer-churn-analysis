
-- Database: PostgreSQL
-- Dataset: Telco Customer Churn (7,043 customers)
-- Table: customers



-- 1. Overall Churn Rate
-- Business question: What % of our customer base has churned?
SELECT
    COUNT(*) AS total_customers,
    SUM(CASE WHEN churn = 'Yes' THEN 1 ELSE 0 END) AS churned_customers,
    ROUND(100.0 * SUM(CASE WHEN churn = 'Yes' THEN 1 ELSE 0 END) / COUNT(*), 2) AS churn_rate_pct
FROM customers;
-- Result: 7043 total | 1869 churned | 26.54% churn rate


-- 2. Churn Rate by Contract Type
-- Business question: Which contract type has the highest churn risk?
SELECT
    contract,
    COUNT(*) AS total_customers,
    SUM(CASE WHEN churn = 'Yes' THEN 1 ELSE 0 END) AS churned,
    ROUND(100.0 * SUM(CASE WHEN churn = 'Yes' THEN 1 ELSE 0 END) / COUNT(*), 2) AS churn_rate_pct
FROM customers
GROUP BY contract
ORDER BY churn_rate_pct DESC;
-- Result: Month-to-month 42.71% | One year 11.27% | Two year 2.83%


-- 3. Revenue at Risk (Monthly)
-- Business question: How much monthly recurring revenue is at risk due to churned customers?
SELECT
    ROUND(SUM(monthlycharges), 2) AS monthly_revenue_at_risk
FROM customers
WHERE churn = 'Yes';
-- Result: 139,130.85


-- 4. Average Tenure: Churned vs Retained Customers
-- Business question: Do customers leave early, or after a long relationship?
SELECT
    churn,
    ROUND(AVG(tenure), 1) AS avg_tenure_months,
    ROUND(AVG(monthlycharges), 2) AS avg_monthly_charges
FROM customers
GROUP BY churn;
-- Result: Retained -> 37.6 months, $61.27 | Churned -> 18.0 months, $74.44


-- 5. Churn Rate by Payment Method
-- Business question: Are certain payment methods linked to higher churn?
SELECT
    paymentmethod,
    COUNT(*) AS total_customers,
    SUM(CASE WHEN churn = 'Yes' THEN 1 ELSE 0 END) AS churned,
    ROUND(100.0 * SUM(CASE WHEN churn = 'Yes' THEN 1 ELSE 0 END) / COUNT(*), 2) AS churn_rate_pct
FROM customers
GROUP BY paymentmethod
ORDER BY churn_rate_pct DESC;
-- Result: Electronic check 45.29% | Mailed check 19.11% | Bank transfer 16.71% | Credit card 15.24%


-- 6. Churn Rate by Internet Service Type
SELECT
    internetservice,
    COUNT(*) AS total_customers,
    SUM(CASE WHEN churn = 'Yes' THEN 1 ELSE 0 END) AS churned,
    ROUND(100.0 * SUM(CASE WHEN churn = 'Yes' THEN 1 ELSE 0 END) / COUNT(*), 2) AS churn_rate_pct
FROM customers
GROUP BY internetservice
ORDER BY churn_rate_pct DESC;
-- Result: Fiber optic 41.89% | DSL 18.96% | No internet service ~7%


-- 7. Tenure Buckets vs Churn Rate (CTE + CASE binning)
-- Business question: At what stage of the customer lifecycle is churn highest?
WITH tenure_buckets AS (
    SELECT
        CASE
            WHEN tenure <= 6 THEN '0-6 months'
            WHEN tenure <= 12 THEN '6-12 months'
            WHEN tenure <= 24 THEN '12-24 months'
            ELSE '24+ months'
        END AS tenure_group,
        churn
    FROM customers
)
SELECT
    tenure_group,
    COUNT(*) AS total_customers,
    SUM(CASE WHEN churn = 'Yes' THEN 1 ELSE 0 END) AS churned,
    ROUND(100.0 * SUM(CASE WHEN churn = 'Yes' THEN 1 ELSE 0 END) / COUNT(*), 2) AS churn_rate_pct
FROM tenure_buckets
GROUP BY tenure_group
ORDER BY
    CASE tenure_group
        WHEN '0-6 months' THEN 1
        WHEN '6-12 months' THEN 2
        WHEN '12-24 months' THEN 3
        ELSE 4
    END;
-- Result: 0-6mo 52.94% | 6-12mo 35.89% | 12-24mo 28.71% | 24+mo 14.04%


-- 8. Top 10 Highest-Value Churned Customers
-- Business question: Which churned customers represented the biggest revenue loss?
SELECT
    customerid,
    contract,
    tenure,
    monthlycharges,
    totalcharges
FROM customers
WHERE churn = 'Yes'
ORDER BY totalcharges DESC
LIMIT 10;
-- Result: All top 10 highest-value churned customers were on One year or Two year
-- contracts, not Month-to-month -- showing long-tenure losses carry the highest
-- revenue impact even though month-to-month churns most frequently.


-- 9. Window Function: Top 5 Highest-Paying Churned Customers Within Each Contract Type
-- Business question: Who are the highest-value churn losses, fairly represented across segments?
WITH ranked_customers AS (
    SELECT
        customerid,
        contract,
        monthlycharges,
        RANK() OVER (PARTITION BY contract ORDER BY monthlycharges DESC) AS charge_rank
    FROM customers
    WHERE churn = 'Yes'
)
SELECT *
FROM ranked_customers
WHERE charge_rank <= 5;
-- Result: Returns 15 rows (top 5 highest-paying churned customers per contract type).
-- Demonstrates PARTITION BY: ranks reset within each contract type group instead
-- of one single ranking across all churned customers.


-- 10. Number of Add-on Services vs Churn Rate
-- Business question: Does having more add-on services reduce churn?
WITH service_count AS (
    SELECT
        customerid,
        churn,
        (CASE WHEN onlinesecurity = 'Yes' THEN 1 ELSE 0 END +
         CASE WHEN onlinebackup = 'Yes' THEN 1 ELSE 0 END +
         CASE WHEN deviceprotection = 'Yes' THEN 1 ELSE 0 END +
         CASE WHEN techsupport = 'Yes' THEN 1 ELSE 0 END +
         CASE WHEN streamingtv = 'Yes' THEN 1 ELSE 0 END +
         CASE WHEN streamingmovies = 'Yes' THEN 1 ELSE 0 END) AS num_services
    FROM customers
)
SELECT
    num_services,
    COUNT(*) AS total_customers,
    SUM(CASE WHEN churn = 'Yes' THEN 1 ELSE 0 END) AS churned,
    ROUND(100.0 * SUM(CASE WHEN churn = 'Yes' THEN 1 ELSE 0 END) / COUNT(*), 2) AS churn_rate_pct
FROM service_count
GROUP BY num_services
ORDER BY num_services;
-- Result: 1 service 45.76% churn -> 6 services 5.28% churn.
-- Strongest retention insight: more add-on services strongly correlates with lower churn.