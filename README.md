🚨 RedFlag: The Fraud Files
A production-grade fraud detection engine built entirely in pure SQL, designed to uncover sophisticated financial crimes across 200,000 synthetic transactions for a simulated Indian payment aggregator.

🛠️ Tech Stack
Database Management System: MySQL (Version 8.x)

Query Language: Advanced SQL

Aggregations & Conditional Logic (GROUP BY, HAVING, CASE WHEN)

Subqueries & Correlations (EXISTS)

Common Table Expressions (CTEs)

Window Functions (ROW_NUMBER(), LAG(), OVER (PARTITION BY))

💡 Project Highlights & Architecture
Real-world fintech fraud analytics rarely relies on complex machine learning right out of the box; instead, it runs on high-performance, precision SQL queries. This project processes a denormalized dataset of 200,000 transactions to simulate a live production environment, catching 12 distinct fraud vectors categorized into three operational tiers:

Tier 1 (Behavioral Baselines): Detects automated scripting through velocity tracking (>=30 daily transactions), round-amount money laundering clusters, micro-transaction card testing, failed-then-succeeded attempt sequences, and odd-hour bot activity concentrations.

Tier 2 (Advanced Relationships): Uncovers rapid fund-routing mule accounts via correlated subqueries, chargeback-heavy refund abuse patterns, multi-step CTE-based merchant collusion, and regulatory KYC-dodging structuring (exact ₹9,999 limits).

Tier 3 (Complex Anomalies & Syndicates): Employs window functions to calculate 6-month baseline velocity spikes and isolates physically impossible geographic jumps (two distinct cities within a 60-minute window).

⚙️ Step-by-Step Local Setup
Follow these instructions to set up and run the detection queries locally on your machine.

Prerequisites
MySQL Server & MySQL Workbench installed.

Installation Steps
Clone the Repository:

Bash
git clone https://github.com/Tanmay-Bokade/RedFlag-Fraud-Detection.git <br>
cd RedFlag-Fraud-Detection <br>
Configure Workbench Timeout (Recommended for Large Files):

Open MySQL Workbench.

Go to Edit > Preferences > SQL Editor.

Set DBMS connection read timeout to 600 seconds to prevent bulk-import timeouts. Click OK and restart Workbench.

Import the Dataset:

Download or locate the dataset file (redflag_transactions.sql). (Note: Due to file size, ensure it is imported via Workbench script runner or command line).

Open the .sql script in Workbench and execute it (Ctrl + Shift + Enter) to create the redflag database and populate the transactions table.

Run Fraud Detection Queries:

Open a new query tab in MySQL Workbench.

Load and execute queries from RedFlag_Tanmay.sql section by section to view flagged suspect logs and verify analytical findings.

👨‍💻 About the Author
Tanmay Purushottam Bokade

Computer Engineering Student @ VESIT | Tech, AI & Data Enthusiast

Let's connect and build cool things!

💼 LinkedIn: linkedin.com/in/tanmay-bokade

🐙 GitHub: github.com/Tanmay-Bokade
