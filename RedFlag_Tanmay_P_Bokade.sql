-- =====================================================================
-- RedFlag Fraud Detection Submission
-- Student: Tanmay Purushottam Bokade | Batch: DA-DS-1 
-- =====================================================================
USE redflag;
-- =====================================================================
-- PATTERN 1: VELOCITY FRAUD
-- what i am looking for: users doing 30 or more txns in a single day. 
-- normal users do 3 to 8 txns. if someone does 30+, it means they are using bot script.
-- expected suspects: 45 to 55 user days.
-- =====================================================================

SELECT 
    user_id, 
    DATE(txn_time) AS txn_date, 
    COUNT(*) AS dy_cnt 
FROM transactions
GROUP BY user_id, DATE(txn_time)
HAVING COUNT(*) >= 30
ORDER BY dy_cnt DESC;

-- my findings: exactly 50 suspect user-days flagged here. count is well within the 45-55 range.
-- top fraudster is user 14556 with 60 txns on 2024-05-28, followed by user 14569 doing 60 txns on 2024-04-03.

-- =====================================================================
-- PATTERN 2: ROUND-AMOUNT CLUSTERING
-- what i am looking for: users with 15+ txns having exact round amounts (100, 500, 1000 etc).
-- real e-commerce txns usually have odd amounts due to taxes. this is money laundering.
-- expected suspects: exactly 25.
-- =====================================================================

SELECT 
    user_id, 
    COUNT(*) AS rnd_amt_cnt
FROM transactions
WHERE amount IN (100, 200, 500, 1000, 2000, 5000, 10000)
GROUP BY user_id
HAVING COUNT(*) >= 15
ORDER BY rnd_amt_cnt DESC;

-- my findings: caught exactly 25 users showing clear money laundering patterns.
-- user 14533 is at the top with 30 round txns, followed by user 14534 with 30 txns too. completely unnatural behaviour.

-- =====================================================================
-- PATTERN 3: CARD TESTING
-- what i am looking for: users making 30+ micro txns (under rs 10) in a single day.
-- fraudsters do this to check if stolen credit cards are still active.
-- expected suspects: exactly 20.
-- =====================================================================

SELECT 
    user_id, 
    DATE(txn_time) AS test_dt, 
    COUNT(*) AS micro_txns
FROM transactions
WHERE amount < 10
GROUP BY user_id, DATE(txn_time)
HAVING COUNT(*) >= 30
ORDER BY micro_txns DESC;

-- my findings: found exactly 20 suspect accounts doing card testing. 
-- top script runner is user 14569 doing 60 micro txns on 2024-04-03, followed closely by user 14556.

-- =====================================================================
-- PATTERN 4: FAILED-THEN-SUCCEEDED
-- what i am looking for: users with 20 or more FAILED transactions.
-- normal users rarely fail this much. high failures mean automated guessing scripts.
-- expected suspects: exactly 25.
-- =====================================================================

SELECT 
    user_id, 
    COUNT(*) AS failed_cnt
FROM transactions
WHERE status = 'FAILED'
GROUP BY user_id
HAVING COUNT(*) >= 20
ORDER BY failed_cnt DESC;

-- my findings: caught exactly 25 accounts running card guessing scripts.
-- user 14595 is at the top with 35 failures, followed by 14593 with 34 fails. definitely not normal human behaviour.


-- =====================================================================
-- PATTERN 5: ODD-HOUR CONCENTRATION
-- what i am looking for: users where 80%+ of their activity is between 2 AM and 5 AM.
-- regular people sleep. bots run scripts during odd hours. requires min 30 total txns.
-- expected suspects: exactly 20.
-- =====================================================================

SELECT 
    user_id,
    COUNT(*) AS total_txn,
    SUM(CASE WHEN HOUR(txn_time) BETWEEN 2 AND 4 THEN 1 ELSE 0 END) AS night_txn,
    (SUM(CASE WHEN HOUR(txn_time) BETWEEN 2 AND 4 THEN 1 ELSE 0 END) / COUNT(*)) * 100 AS odd_hr_ratio
FROM transactions
GROUP BY user_id
HAVING total_txn >= 30 
   AND odd_hr_ratio >= 80
ORDER BY odd_hr_ratio DESC, total_txn DESC;

-- my findings: found exactly 20 users operating mostly at night. 
-- user 14606 did 49 out of 52 txns in odd hours (approx 94% ratio). this is pure bot behavior.


-- =====================================================================
-- PATTERN 6: MULE ACCOUNTS
-- what i am looking for: users getting a CREDIT and doing a DEBIT of 70%+ amount within 30 mins.
-- this means they are moving stolen money fast. looking for 5+ instances.
-- expected suspects: exactly 30.
-- =====================================================================

SELECT 
    c.user_id,
    COUNT(*) AS mul_instances
FROM transactions c
WHERE c.txn_type = 'CREDIT'
  AND EXISTS (
      SELECT 1
      FROM transactions d
      WHERE d.user_id = c.user_id
        AND d.txn_type = 'DEBIT'
        AND d.txn_time > c.txn_time
        AND TIMESTAMPDIFF(MINUTE, c.txn_time, d.txn_time) <= 30
        AND d.amount >= 0.70 * c.amount
  )
GROUP BY c.user_id
HAVING COUNT(*) >= 5
ORDER BY mul_instances DESC;

-- my findings: caught exactly 30 mule accounts. 
-- these accounts receive funds and immediately route them out. user 14637 has 15 such quick in-and-out transfers.

-- =====================================================================
-- PATTERN 7: REFUND ABUSE
-- what i am looking for: users with 20+ txns and refund ratio > 40%.
-- normal refund rate is below 5%. anything over 40% is mostly a chargeback fraud.
-- expected suspects: 24 to 25.
-- =====================================================================

SELECT 
    user_id,
    COUNT(*) AS total_txns,
    SUM(CASE WHEN txn_type = 'REFUND' THEN 1 ELSE 0 END) AS refund_cnt,
    (SUM(CASE WHEN txn_type = 'REFUND' THEN 1 ELSE 0 END) / COUNT(*)) * 100 AS refund_pct
FROM transactions
GROUP BY user_id
HAVING total_txns >= 20 
   AND refund_pct > 40
ORDER BY refund_pct DESC;

-- my findings: exactly 24 suspects found doing refund abuse. 
-- user 14662 has 25 refunds out of 39 total txns (64% refund rate). this is clearly chargeback fraud.


-- =====================================================================
-- PATTERN 8: MERCHANT COLLUSION
-- what i am looking for: merchants where top 5 users contribute > 60% of total volume.
-- normal merchants have a long tail of customers. this pattern shows laundering via fake txns.
-- expected suspects: exactly 15.
-- =====================================================================

WITH mer_total AS (
    SELECT merchant_id, SUM(amount) AS total_vol
    FROM transactions
    GROUP BY merchant_id
),
usr_mer_vol AS (
    SELECT merchant_id, user_id, SUM(amount) AS usr_vol
    FROM transactions
    GROUP BY merchant_id, user_id
),
ranked_usrs AS (
    SELECT merchant_id, user_id, usr_vol,
           ROW_NUMBER() OVER(PARTITION BY merchant_id ORDER BY usr_vol DESC) as rnk
    FROM usr_mer_vol
),
top5_vol AS (
    SELECT merchant_id, SUM(usr_vol) AS t5_vol
    FROM ranked_usrs
    WHERE rnk <= 5
    GROUP BY merchant_id
)
SELECT 
    t.merchant_id,
    t.total_vol,
    top5.t5_vol,
    (top5.t5_vol / t.total_vol) * 100 AS top5_ratio
FROM mer_total t
JOIN top5_vol top5 ON t.merchant_id = top5.merchant_id
WHERE (top5.t5_vol / t.total_vol) * 100 > 60
ORDER BY top5_ratio DESC;

-- my findings: caught exactly 15 merchants showing clear collusion. 
-- merchant ids 1 to 15 have almost 99% of their volume coming from just their top 5 users. this is a laundering setup.


-- =====================================================================
-- PATTERN 9: JUST-UNDER-THRESHOLD (STRUCTURING)
-- what i am looking for: users doing 10 or more txns of exactly 9999.
-- kyc limit is 10000. so doing 9999 is a classic trick to avoid kyc checks (structuring).
-- expected suspects: exactly 20.
-- =====================================================================

SELECT 
    user_id, 
    COUNT(*) AS struct_cnt
FROM transactions
WHERE amount = 9999.00
GROUP BY user_id
HAVING COUNT(*) >= 10
ORDER BY struct_cnt DESC;

-- my findings: found exactly 20 accounts doing structuring. 
-- top suspect 14680 made 25 txns of exactly 9999 to dodge the 10k kyc limit.



-- =====================================================================
-- PATTERN 10: DORMANT-THEN-ACTIVE
-- what i am looking for: users who had a 90+ days gap and then suddenly did 15+ txns.
-- accounts sleeping for 3 months suddenly waking up means someone hijacked them.
-- expected suspects: around 25 to 27.
-- =====================================================================

WITH usr_gaps AS (
    SELECT 
        user_id,
        txn_time,
        LAG(txn_time) OVER(PARTITION BY user_id ORDER BY txn_time) AS prev_txn_time
    FROM transactions
),
hacked_accs AS (
    SELECT user_id, txn_time AS wakeup_time
    FROM usr_gaps
    WHERE prev_txn_time IS NOT NULL 
      AND TIMESTAMPDIFF(DAY, prev_txn_time, txn_time) >= 90
)
SELECT 
    t.user_id, 
    COUNT(t.txn_id) AS post_gap_txns
FROM hacked_accs h
JOIN transactions t 
  ON t.user_id = h.user_id 
  AND t.txn_time >= h.wakeup_time
GROUP BY t.user_id
HAVING COUNT(t.txn_id) >= 15
ORDER BY post_gap_txns DESC;

-- my findings: found 26 accounts that woke up after 90+ days.
-- user 14526 suddenly did 55 txns after a long gap. this is a clear sign of account takeover.


-- =====================================================================
-- PATTERN 11: VELOCITY SPIKE
-- what i am looking for: users whose peak monthly txns are 5x more than their average.
-- sudden spikes usually mean the account is compromised. peak must be 20+.
-- expected suspects: around 35 to 45.
-- =====================================================================

WITH monthly_counts AS (
    SELECT 
        user_id,
        DATE_FORMAT(txn_time, '%Y-%m') AS txn_month,
        COUNT(*) AS monthly_txns
    FROM transactions
    GROUP BY user_id, DATE_FORMAT(txn_time, '%Y-%m')
),
user_stats AS (
    SELECT 
        user_id,
        SUM(monthly_txns) / 6.0 AS avg_txns,
        MAX(monthly_txns) AS peak_txns
    FROM monthly_counts
    GROUP BY user_id
)
SELECT 
    user_id,
    avg_txns,
    peak_txns,
    (peak_txns / avg_txns) AS spike_ratio
FROM user_stats
WHERE peak_txns >= 20
  AND (peak_txns / avg_txns) >= 5
ORDER BY spike_ratio DESC;

-- my findings: detected 66 users showing a massive velocity spike over their 6-month baseline.
-- users like 14575 and 14573 hit the max spike ratio of 6.0, making it a textbook case of account takeover.


-- =====================================================================
-- PATTERN 12: GEOGRAPHIC IMPOSSIBILITY
-- what i am looking for: a user transacting in 2 different cities within 60 mins.
-- this is physically impossible. it means two different people are using the compromised account.
-- expected suspects: exactly 15.
-- =====================================================================

WITH city_lags AS (
    SELECT 
        user_id,
        city,
        txn_time,
        LAG(city) OVER (PARTITION BY user_id ORDER BY txn_time) AS prev_city,
        LAG(txn_time) OVER (PARTITION BY user_id ORDER BY txn_time) AS prev_txn_time
    FROM transactions
)
SELECT 
    user_id,
    COUNT(*) AS impossible_jumps
FROM city_lags
WHERE prev_city IS NOT NULL 
  AND city != prev_city
  AND TIMESTAMPDIFF(MINUTE, prev_txn_time, txn_time) <= 60
GROUP BY user_id
ORDER BY impossible_jumps DESC;

-- my findings: found exactly 15 suspects hitting the geographic impossibility pattern.
-- user 14755 had 8 impossible city jumps within 60 mins. definitely a stolen card used by a syndicate across different locations.