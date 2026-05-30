-- ============================================================
-- PROJECT : Microfinance Institution (MFI) Loan Portfolio Analysis
-- Domain  : Financial Services | Microfinance
-- Tool    : SQLite / PostgreSQL / MySQL compatible
-- ============================================================
-- CONTEXT :
--   A microfinance institution gives small loans (₹5,000–₹30,000)
--   to low-income borrowers — street vendors, farmers, weavers —
--   across 8 Indian states. The credit team uses this data to
--   track loans, spot late payments, and monitor field officers.
-- ============================================================


-- ─────────────────────────────────────────────────────────────
-- SECTION 0 : SCHEMA
-- ─────────────────────────────────────────────────────────────

DROP TABLE IF EXISTS mfi_loans;

CREATE TABLE mfi_loans (
    loan_id             TEXT    PRIMARY KEY,   -- e.g. LN-0001
    borrower_id         TEXT    NOT NULL,      -- e.g. BRW-0001
    state               TEXT    NOT NULL,      -- Indian state
    occupation          TEXT    NOT NULL,      -- Borrower's livelihood
    loan_amount         REAL    NOT NULL,      -- Principal disbursed (INR)
    interest_rate_pct   REAL    NOT NULL,      -- Annual interest rate (%)
    tenure_months       INTEGER NOT NULL,      -- Loan duration in months
    disbursement_date   DATE    NOT NULL,      -- Date loan was given
    repayment_frequency TEXT    NOT NULL,      -- Weekly / Bi-Weekly / Monthly
    loan_purpose        TEXT    NOT NULL,      -- Why the borrower needed it
    loan_officer_id     TEXT    NOT NULL,      -- Field officer who managed it
    emi_amount          REAL    NOT NULL,      -- Monthly repayment amount (INR)
    days_past_due       INTEGER DEFAULT 0,     -- Days the borrower is late (0 = on time)
    loan_status         TEXT    NOT NULL,      -- Active / Closed / NPA
    credit_score        INTEGER                -- Internal score: 300 (worst) – 850 (best)
);

-- Load data (SQLite):
--   .mode csv
--   .import mfi_loan_data.csv mfi_loans


-- ─────────────────────────────────────────────────────────────
-- SECTION 1 : DATA EXPLORATION  (run these first)
-- ─────────────────────────────────────────────────────────────

-- How many loans are in the table?
SELECT COUNT(*) AS total_loans FROM mfi_loans;

-- What does the data look like?
SELECT * FROM mfi_loans LIMIT 5;

-- What are the unique loan statuses?
SELECT DISTINCT loan_status FROM mfi_loans;

-- What states are covered?
SELECT DISTINCT state FROM mfi_loans ORDER BY state;

-- What is the range of loan amounts?
SELECT
    MIN(loan_amount) AS smallest_loan,
    MAX(loan_amount) AS largest_loan,
    ROUND(AVG(loan_amount), 0) AS average_loan
FROM mfi_loans;


-- ══════════════════════════════════════════════════════════════
-- SECTION 2 : BUSINESS QUESTIONS
-- ══════════════════════════════════════════════════════════════


-- ─────────────────────────────────────────────────────────────
-- BQ-01  How many loans are Active, Closed, and NPA?
--
-- Why it matters:
--   The manager wants a simple count of the portfolio by status
--   every morning — the very first thing any lending team checks.
-- ─────────────────────────────────────────────────────────────

SELECT
    loan_status,
    COUNT(*)                       AS number_of_loans,
    ROUND(SUM(loan_amount), 0)     AS total_amount_inr
FROM mfi_loans
GROUP BY loan_status
ORDER BY number_of_loans DESC;


-- ─────────────────────────────────────────────────────────────
-- BQ-02  Which state has the most loans disbursed?
--
-- Why it matters:
--   The branch expansion team wants to see where the institution
--   is most active, and how much money has gone out per state.
-- ─────────────────────────────────────────────────────────────

SELECT
    state,
    COUNT(*)                       AS total_loans,
    ROUND(SUM(loan_amount), 0)     AS total_disbursed_inr,
    ROUND(AVG(loan_amount), 0)     AS avg_loan_size
FROM mfi_loans
GROUP BY state
ORDER BY total_loans DESC;


-- ─────────────────────────────────────────────────────────────
-- BQ-03  What are the most common reasons borrowers take loans?
--
-- Why it matters:
--   The product team wants to know which loan purposes are most
--   popular so they can design targeted loan products.
-- ─────────────────────────────────────────────────────────────

SELECT
    loan_purpose,
    COUNT(*)                       AS loan_count,
    ROUND(AVG(loan_amount), 0)     AS avg_loan_amount
FROM mfi_loans
GROUP BY loan_purpose
ORDER BY loan_count DESC;


-- ─────────────────────────────────────────────────────────────
-- BQ-04  Which occupations borrow the most money?
--
-- Why it matters:
--   Credit team wants to understand their customer base —
--   who is taking the largest loans and in what profession.
-- ─────────────────────────────────────────────────────────────

SELECT
    occupation,
    COUNT(*)                       AS number_of_borrowers,
    ROUND(SUM(loan_amount), 0)     AS total_amount_borrowed,
    ROUND(AVG(loan_amount), 0)     AS avg_loan_size
FROM mfi_loans
GROUP BY occupation
ORDER BY total_amount_borrowed DESC;


-- ─────────────────────────────────────────────────────────────
-- BQ-05  How many borrowers are paying late? (Late Payment Check)
--
-- Why it matters:
--   The collections team does a daily check — how many borrowers
--   are behind on payments, and by how many days?
--   Days Past Due (DPD) = 0 means on time.
-- ─────────────────────────────────────────────────────────────

SELECT
    CASE
        WHEN days_past_due = 0           THEN 'On Time'
        WHEN days_past_due BETWEEN 1 AND 30  THEN '1–30 Days Late'
        WHEN days_past_due BETWEEN 31 AND 90 THEN '31–90 Days Late'
        ELSE                                  'Over 90 Days Late'
    END                            AS payment_status,
    COUNT(*)                       AS borrower_count,
    ROUND(SUM(loan_amount), 0)     AS amount_at_risk
FROM mfi_loans
GROUP BY payment_status
ORDER BY MIN(days_past_due);


-- ─────────────────────────────────────────────────────────────
-- BQ-06  Which loan officer manages the most loans?
--
-- Why it matters:
--   Operations team checks workload balance — if one officer
--   has too many loans they may be overstretched in the field.
-- ─────────────────────────────────────────────────────────────

SELECT
    loan_officer_id,
    COUNT(*)                       AS loans_handled,
    ROUND(SUM(loan_amount), 0)     AS portfolio_value,
    ROUND(AVG(loan_amount), 0)     AS avg_loan_size
FROM mfi_loans
GROUP BY loan_officer_id
ORDER BY loans_handled DESC
LIMIT 10;


-- ─────────────────────────────────────────────────────────────
-- BQ-07  Which loan officer has the most NPA (defaulted) loans?
--
-- Why it matters:
--   HR and the credit team use this in performance reviews.
--   An officer with many NPAs may need extra training or
--   their portfolio reassigned.
-- ─────────────────────────────────────────────────────────────

SELECT
    loan_officer_id,
    COUNT(*)                                                      AS total_loans,
    SUM(CASE WHEN loan_status = 'NPA' THEN 1 ELSE 0 END)         AS npa_loans,
    ROUND(100.0 * SUM(CASE WHEN loan_status = 'NPA' THEN 1 ELSE 0 END)
          / COUNT(*), 1)                                          AS npa_percentage
FROM mfi_loans
GROUP BY loan_officer_id
ORDER BY npa_percentage DESC
LIMIT 10;


-- ─────────────────────────────────────────────────────────────
-- BQ-08  What is the average credit score per state?
--
-- Why it matters:
--   The risk team wants to know which states have weaker
--   borrower profiles on average — useful for adjusting
--   loan limits region by region.
-- ─────────────────────────────────────────────────────────────

SELECT
    state,
    COUNT(*)                       AS borrowers,
    ROUND(AVG(credit_score), 1)    AS avg_credit_score,
    MIN(credit_score)              AS lowest_score,
    MAX(credit_score)              AS highest_score
FROM mfi_loans
GROUP BY state
ORDER BY avg_credit_score DESC;


-- ─────────────────────────────────────────────────────────────
-- BQ-09  How many loans were given each year?
--
-- Why it matters:
--   Finance team tracks whether the business is growing
--   year over year — a basic but essential trend check.
-- ─────────────────────────────────────────────────────────────

SELECT
    STRFTIME('%Y', disbursement_date)   AS year,
    -- PostgreSQL: EXTRACT(YEAR FROM disbursement_date)
    COUNT(*)                            AS loans_disbursed,
    ROUND(SUM(loan_amount), 0)          AS total_disbursed_inr,
    ROUND(AVG(loan_amount), 0)          AS avg_loan_size
FROM mfi_loans
GROUP BY year
ORDER BY year;


-- ─────────────────────────────────────────────────────────────
-- BQ-10  What is the average EMI per repayment frequency type?
--
-- Why it matters:
--   Product team wants to understand the payment burden on
--   borrowers across different repayment schedules.
-- ─────────────────────────────────────────────────────────────

SELECT
    repayment_frequency,
    COUNT(*)                       AS loan_count,
    ROUND(AVG(emi_amount), 2)      AS avg_emi,
    ROUND(AVG(loan_amount), 0)     AS avg_loan_size,
    ROUND(AVG(tenure_months), 1)   AS avg_tenure_months
FROM mfi_loans
GROUP BY repayment_frequency
ORDER BY avg_emi DESC;


-- ─────────────────────────────────────────────────────────────
-- BQ-11  Find all loans where the borrower is late but the
--        loan is still marked Active (not yet NPA)
--
-- Why it matters:
--   The collections team uses this as a daily follow-up list —
--   borrowers who are overdue but haven't defaulted yet.
--   These need a phone call or field visit today.
-- ─────────────────────────────────────────────────────────────

SELECT
    loan_id,
    borrower_id,
    state,
    occupation,
    loan_amount,
    days_past_due,
    loan_officer_id
FROM mfi_loans
WHERE loan_status = 'Active'
  AND days_past_due > 0
ORDER BY days_past_due DESC;


-- ─────────────────────────────────────────────────────────────
-- BQ-12  What is the total interest income the institution
--        expects from all Active loans?
--
-- Why it matters:
--   The CFO asks this every quarter — "how much interest
--   will we earn from our current live loans?"
--   Formula: Annual Interest = Loan Amount × Rate / 100
-- ─────────────────────────────────────────────────────────────

SELECT
    state,
    COUNT(*)                                                AS active_loans,
    ROUND(SUM(loan_amount), 0)                             AS principal_outstanding,
    ROUND(SUM(loan_amount * interest_rate_pct / 100), 0)   AS expected_annual_interest
FROM mfi_loans
WHERE loan_status = 'Active'
GROUP BY state
ORDER BY expected_annual_interest DESC;


-- ─────────────────────────────────────────────────────────────
-- BQ-13  Which are the top 10 largest loans given out,
--        and what is their current status?
--
-- Why it matters:
--   Large loans carry more risk. Senior management always
--   wants to know the status of the biggest exposures.
-- ─────────────────────────────────────────────────────────────

SELECT
    loan_id,
    borrower_id,
    state,
    occupation,
    loan_amount,
    loan_status,
    days_past_due,
    loan_officer_id
FROM mfi_loans
ORDER BY loan_amount DESC
LIMIT 10;


-- ─────────────────────────────────────────────────────────────
-- BQ-14  How does loan tenure affect the average loan size?
--
-- Why it matters:
--   Product team wants to know if borrowers who take longer
--   loans also take larger amounts — helps in designing
--   the right tenure–amount combinations.
-- ─────────────────────────────────────────────────────────────

SELECT
    tenure_months,
    COUNT(*)                       AS loan_count,
    ROUND(AVG(loan_amount), 0)     AS avg_loan_amount,
    ROUND(AVG(emi_amount), 2)      AS avg_emi
FROM mfi_loans
GROUP BY tenure_months
ORDER BY tenure_months;


-- ─────────────────────────────────────────────────────────────
-- BQ-15  BONUS (Intermediate): Rank loan officers by
--        the total value of loans they have managed.
--
-- Why it matters:
--   Leadership wants to recognize top performers by volume.
--   Uses a window function RANK() — a step up from basic GROUP BY.
-- ─────────────────────────────────────────────────────────────

SELECT
    loan_officer_id,
    COUNT(*)                               AS total_loans,
    ROUND(SUM(loan_amount), 0)             AS total_portfolio_value,
    RANK() OVER (
        ORDER BY SUM(loan_amount) DESC
    )                                      AS portfolio_rank
FROM mfi_loans
GROUP BY loan_officer_id
ORDER BY portfolio_rank;


-- ══════════════════════════════════════════════════════════════
-- END OF PROJECT
-- ══════════════════════════════════════════════════════════════
