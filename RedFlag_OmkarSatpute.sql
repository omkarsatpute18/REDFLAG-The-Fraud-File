-- =====================================================================
-- RedFlag — Fraud Detection Submission
-- Student: Omkar Satpute | Batch: DA-DS-July
-- =====================================================================

USE redflag;

-- =====================================================================
-- PATTERN 1 · VELOCITY FRAUD
-- What I'm looking for: users with 30+ transactions in a single day
-- Expected suspects: ~50
SELECT user_id, DATE(txn_time) AS attack_date, COUNT(*) AS daily_txn_count FROM transactions
GROUP BY user_id, DATE(txn_time)
HAVING COUNT(*) >= 30
ORDER BY daily_txn_count DESC;

-- My findings: 52 suspect user-days flagged.
-- Top 3 fraudsters by transaction count: user 14523 (45 txns on 2024-04-12),
-- user 14508 (44 txns on 2024-02-28), user 14515 (43 txns on 2024-05-19).
-- =====================================================================

-- =====================================================================
-- PATTERN 2 · ROUND-AMOUNT CLUSTERING
-- we have to filter out A user with 15+ exactly-round transactions so there are 25+ suspects.
-- Expected suspects : ~ 25 
SELECT user_id,COUNT(*) AS round_amount_txns FROM transactions
WHERE amount IN (100, 200, 500, 1000, 2000, 5000, 10000)
GROUP BY user_id
HAVING COUNT(*) >= 15
ORDER BY round_amount_txns DESC;
-- my findings: ~ 28 users found

-- ===================================================================== 

-- ===================================================================== 
-- PATTERN 3 ·  CARD TESTING
-- we have to find out the fake card transaction with the small amount like Rs.10 expected users are around 30+
-- Expected Suspects: ~ 25
select user_id,DATE(txn_time) as txn_date ,count(*) as small_txn_count from transactions
where amount < 10
group by user_id,DATE(txn_time)
hAVing count(*) >= 30
order by small_txn_count desc;
-- Here I have found that there are around 19 users with more than 30 suspected transactions.
-- My findings: ~ 19

-- ===================================================================== 

-- ===================================================================== 
-- PATTERN 4 ·  FAILED-THEN-SUCCEEDED
-- In that we have to identify the user who enter the wrong information many times if a user is real then there is less chances of getting wrong info from them
-- Expected Suspects: ~25
select user_id,count(*) as failed_txn_count from transactions
where status = "FAILED"
group by user_id
HavIng count(*) >= 20
order by failed_txn_count desc;

-- Here I have found that there is something around 24 user are found with 20+ times entered wrong information
-- My Findings: ~ 24 users

-- ===================================================================== 


-- ===================================================================== 
-- PATTERN 5 ·  ODD-HOUR CONCERNTRATION
-- Real indian user transact betweeen 8am to 11 pm most of the time fraudlant time is 2 am to 5 am in north american time
-- Task is to find out the user who doing 80% or more than it transaction between 2 am to 5 am
-- Expected suspects: ~20

select user_id,count(*) as fraud_transaction_time,
sum(
case when(txn_time) between 2 and 4 then 1 else 0 end
) as odd_hour_txn from transactions
group by user_id
Having count(*) >= 30
and
SUM(
CASE
WHEN HOUR(txn_time) BETWEEN 2 AND 4 THEN 1
ELSE 0
END) / COUNT(*) >= 0.80
ORDER BY odd_hour_txn DESC;

-- My Findings: ~19 user who did transaction between 2 am to 5 am

-- =====================================================================


-- ===================================================================== 
-- PATTERN 6 ·  MULE ACCOUNTS
-- The mule account is commision bases account which is used to credit amount and take immediate debit from it and mule account manager takes commision
-- There are something around 20 suspects
select user_id,count(*) as credit_tnx from transactions
where txn_type = "CREDIT"
group by user_id
having count(*) >= 8
order by credit_tnx desc;

-- My Findings: ~ 29

-- =====================================================================


-- =====================================================================
-- PATTERN 7 ·  REFUND ABUSE
-- Expected suspects: ~24-25

select user_id,count(*) as abuse_txn,
sum(
case
when txn_type = "REFUND" then 1 else 0
end)
as refund_abuse from transactions
group by user_id
having count(*) >= 20
and
SUM(
CASE
WHEn txn_type = "REFUND" then 1 else 0
END) / COUNT(*) > 0.40

order by refund_abuse desc;

-- My Findings: Exactly 24 user

-- =====================================================================


-- =====================================================================
-- PATTERN 8 ·  MERCHANT COLLUSION
-- Expected suspects: ~15 

WITH user_totals AS (
    SELECT merchant_id, user_id, SUM(amount) AS user_total
    FROM transactions
    GROUP BY merchant_id, user_id
),
ranked AS (
    SELECT *,
           ROW_NUMBER() OVER (
               PARTITION BY merchant_id
               ORDER BY user_total DESC
           ) AS rnk
    FROM user_totals
),
top5 AS (
    SELECT merchant_id, SUM(user_total) AS top5_total
    FROM ranked
    WHERE rnk <= 5
    GROUP BY merchant_id
)
SELECT 
    t.merchant_id,
    t.top5_total,
    SUM(x.amount) AS merchant_total,
    t.top5_total / SUM(x.amount) AS ratio
FROM top5 t
JOIN transactions x
    ON t.merchant_id = x.merchant_id
GROUP BY t.merchant_id, t.top5_total
HAVING t.top5_total / SUM(x.amount) > 0.60
ORDER BY ratio DESC;

-- My findings : 15 merchant store

-- =====================================================================



-- =====================================================================
-- PATTERN 9 · JUST-UNDER-THRESHOLD (STRUCTURING)
-- Here we have to find out the user who did transaction of amount 9999 just to avoid the KYC on transaction above 10000 or above
-- Expected Findings: ~ 20

select user_id,count(*) as txn_amount from transactions
where amount = 9999
group by user_id
having count(*) >= 10 
order by user_id desc;

-- My Findings: there are total 19 findings.

-- =====================================================================


-- =====================================================================
-- PATTERN 10 · DORMANT-THEN-ACTIVE
-- we have to find a user who has a gap of 90+ days between two consecutive transactions, followed by 15+ transactions after the gap.
-- Expected suspects : ~ 25-27 
WITH transaction_gaps AS (
    SELECT
        user_id,
        txn_time,
        LAG(txn_time) OVER (
            PARTITION BY user_id
            ORDER BY txn_time
        ) AS previous_txn_time
    FROM transactions
),

dormant_users AS (
    SELECT
        user_id,
        txn_time AS active_start
    FROM transaction_gaps
    WHERE TIMESTAMPDIFF(DAY, previous_txn_time, txn_time) >= 90
)

SELECT
    d.user_id,
    COUNT(t.txn_id) AS post_gap_txns
FROM dormant_users d
JOIN transactions t
    ON t.user_id = d.user_id
    AND t.txn_time >= d.active_start
GROUP BY d.user_id
HAVING COUNT(t.txn_id) >= 15
ORDER BY post_gap_txns DESC;
-- My Findings: ~ 25 users

-- =====================================================================


-- =====================================================================
-- PATTERN 11 · VELOCITY SPIKE
-- we have to find the a user whose peak monthly transaction count is at least 5x their average monthly transaction count
-- Expected suspects: ~35-40

WITH monthly_txns AS (
    SELECT
        user_id,
        DATE_FORMAT(txn_time, '%Y-%m') AS txn_month,
        COUNT(*) AS monthly_count
    FROM transactions
    GROUP BY user_id, DATE_FORMAT(txn_time, '%Y-%m')
),

user_stats AS (
    SELECT
        user_id,
        AVG(monthly_count) AS avg_monthly_txns,
        MAX(monthly_count) AS peak_monthly_txns
    FROM monthly_txns
    GROUP BY user_id
)

SELECT
    user_id,
    avg_monthly_txns,
    peak_monthly_txns,
    peak_monthly_txns / avg_monthly_txns AS spike_ratio
FROM user_stats
WHERE peak_monthly_txns >= 20
  AND peak_monthly_txns / avg_monthly_txns >= 5
ORDER BY spike_ratio DESC;

-- My Findings: Unexpected but there are only 3-4 user

-- =====================================================================


-- =====================================================================
-- PATTERN 12 · GEOGRAPHIC IMPOSSIBILITY
-- we have to find a user where two consecutive transactions happen in different cities within 60 minutes.
-- Expexted suspects: ~15
WITH previous_transactions AS (
    SELECT
        user_id,
        txn_time,
        city,
        LAG(city) OVER (
            PARTITION BY user_id
            ORDER BY txn_time
        ) AS previous_city,
        LAG(txn_time) OVER (
            PARTITION BY user_id
            ORDER BY txn_time
        ) AS previous_time
    FROM transactions
)

SELECT
    user_id,
    previous_city,
    city AS current_city,
    previous_time,
    txn_time AS current_time,
    TIMESTAMPDIFF(MINUTE, previous_time, txn_time) AS time_difference
FROM previous_transactions
WHERE previous_city <> city
  AND TIMESTAMPDIFF(MINUTE, previous_time, txn_time) <= 60
ORDER BY time_difference;
-- My Findings: ~15 user

-- =====================================================================


