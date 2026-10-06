# Hospital Performance Dashboard (Power BI)

An interactive four-page Power BI report that helps hospital management answer one question: **where is money leaking, where is patient experience failing, and what should be fixed first?**

It tracks patient volume, billing and collections, insurance coverage, out-of-pocket costs, admissions, emergency demand and patient satisfaction. Every page can be filtered by Year-Month, Department, Service Type and Insurance Provider.

---

## Business problem

More than a third of the hospital's billing is unpaid, and patient satisfaction is low. Leadership needs one view that shows:

1. **Revenue at risk**: how much billing is unpaid, whether the problem sits with particular departments, insurers or service types, and how stable collections are month to month.
2. **Patient cost burden**: how much of each bill insurance covers and how much patients pay themselves.
3. **Operational load**: emergency demand, admission rates by department, length of stay by diagnosis and visits by day of the week.
4. **Patient experience**: how satisfied patients are, and which departments score lowest.

---

## Report pages

### 1. Overview
KPI cards for Total Visits, Unique Patients, Total Billed, Coverage %, Unpaid Amount, % Billing Unpaid, Admission Rate, Avg Satisfaction, % Low Satisfaction and % High Satisfaction. Below them: Unpaid % by department, total visits by satisfaction score (1–10), and a monthly trend of total visits and Unpaid %. A key findings panel summarises the page.

### 2. Revenue & Collections
KPI cards for Paid Amount, Unpaid Amount, Insurance Covered, Out of Pocket and Avg Out-of-Pocket per Visit. Below them: paid vs unpaid billing by month, unpaid amount by department, Unpaid % by service type, Unpaid % by insurance provider, and an out-of-pocket % matrix (department × insurer) with heat-map shading. A key findings panel summarises the page.

### 3. Operations & Capacity
KPI cards for Emergency Visits, Emergency %, Admission Rate and Avg Length of Stay. Below them: emergency visits by month with an average line, admission rate by department, average length of stay by diagnosis, and total visits by day of the week. A key findings panel summarises the page.

### 4. Patient Experience
KPI cards for % High Satisfaction and % Low Satisfaction. Below them: number of visits by satisfaction score (1 = worst, 10 = best) and average satisfaction by department, with unpaid amount in the tooltip. A key findings panel summarises the page.

Each page has the same left panel with slicers and navigation buttons (Overview, Revenue, Operations, Experience).

---

## Data preparation (Power Query)

The steps I added in Power Query are in the [`power-query`](power-query) folder, one file per table. Power BI's automatic load steps (Source, Promoted headers, Changed column type) are not included.

**patients** ([`patients.m`](power-query/patients.m))
- Added an **Age Group** column that bands patients into 18–29, 30–44, 45–59 and 60+, so age can be used as a category.
- Merged with the **cities** table on `City ID` (left outer join) and expanded the **City** column, so each patient has a readable city name instead of an ID.

**visits** ([`visits.m`](power-query/visits.m))
- Converted **Date of Visit** and **Follow-Up Visit Date** to the Date type using the en-US locale.
- Converted **Discharge Date** and **Admitted Date** from text to the Date type.
- Renamed `Room Charges(daily rate)` to **Room Daily Rate** for a cleaner field name.
- Replaced `N/A` in **Room Type** with **Not Admitted**, so visits without a hospital stay have a clear label.

**_Measures_data_values**
- Created an empty table to hold all DAX measures in one place.

**departments, diagnoses, insurance, procedures, providers**
- Loaded without any manual changes.

---

## Data quality checks

Before building the insights, I checked the raw data and found issues that affect how the report should be read.

| Issue | What I found | How the report handles it |
|---|---|---|
| Incomplete dates, Oct 2024 – Jan 2025 | Normal months have about 300 visits (10 a day). Oct 2024 has only 45, Nov 2024 has none, and 1–4 Jan 2025 have 160 visits a day. The missing records appear to have been dated into early January. | Monthly trend charts exclude 2024-10 to 2025-01 with a visual-level filter and a note on the chart. Totals still include every visit. |
| Partial final month | May 2025 has only part of the month. | A report-level filter excludes 2025-05 from all pages. |
| Emergency flag vs Service Type | 987 visits with Service Type "Outpatient" are flagged `Emergency Visit = Yes`, so the flag (38.6% of visits) and Service Type (24.6% Emergency) disagree. | The Operations page uses the emergency flag and labels it "based on visits flagged as emergency". |
| Missing insurance coverage | 119 visits have no Insurance Coverage value. | Treated as zero coverage, which slightly raises Out of Pocket. |

---

## Data model

Star schema with `visits` as the fact table.

| Table | Type | Role |
|---|---|---|
| `visits` | Fact | One row per visit: billing, payment status, admission, emergency flag, length of stay, satisfaction |
| `patients` | Dimension | Patient details, Age Group, City |
| `departments` | Dimension | Department names |
| `diagnoses` | Dimension | Diagnosis descriptions |
| `procedures` | Dimension | Procedures performed |
| `providers` | Dimension | Care providers |
| `insurance` | Dimension | Insurance providers |
| `Date` | Dimension | Calculated calendar table (see below) |
| `_Measures_data_values` | Measure table | Holds all DAX measures in one place |

### Date table

Built in DAX so the report has one continuous calendar with no missing days, even on days with no visits. It is linked to `visits[Date of Visit]`. Definition: [`dax/date-table.dax`](dax/date-table.dax).

```dax
Date =
ADDCOLUMNS(
    CALENDAR(DATE(2024,1,1), DATE(2025,5,31)),
    "Year", YEAR([Date]),
    "Month No", MONTH([Date]),
    "Month", FORMAT([Date], "mmm"),
    "Year-Month", FORMAT([Date], "yyyy-mm"),
    "Quarter", "Q" & QUARTER([Date]),
    "Weekday", FORMAT([Date], "ddd"),
    "Weekday No", WEEKDAY([Date], 2)
)
```

| Column | Example | Purpose |
|---|---|---|
| Date | 2024-03-15 | One row per day from 1 Jan 2024 to 31 May 2025 |
| Year | 2024 | Yearly grouping |
| Month No | 3 | Numeric month (calendar order 1–12) |
| Month | Mar | Short month name for labels |
| Year-Month | 2024-03 | Monthly trend axis and slicer; the yyyy-mm format sorts correctly as text |
| Quarter | Q1 | Quarterly grouping |
| Weekday | Fri | Short day name |
| Weekday No | 5 | Monday = 1 to Sunday = 7 |
| Day Name | Fri | Added column used on the day-of-week axis (Operations page); sorted by Weekday No so days show Mon to Sun instead of alphabetically |

---

## DAX measures

All measures are in the `_Measures_data_values` table. Definitions are in [`dax/measures.dax`](dax/measures.dax).

**Design choice:** every dollar total is paired with a rate. Totals such as Unpaid Amount mostly reflect how big a department is, so on their own they point at the busiest departments. Rates such as Unpaid % divide by size, so departments, insurers and service types can be compared fairly. Dollars show where to chase money first; rates show where the process is failing.

### Base measures
These are the building blocks that other measures reuse.

| Measure | Used on dashboard? | Feeds into |
|---|---|---|
| Total Visits | Yes (KPI card, trend, day-of-week chart, score distribution) | Admissions, Admission Rate, Emergency Visits, Emergency %, satisfaction %s, Avg Out-of-Pocket per Visit |
| Total Billed | Yes (KPI card) | Coverage %, Out of Pocket, Paid Amount, Unpaid Amount, Unpaid %, Out of Pocket % |
| Insurance Covered | Yes (Revenue KPI card) | Coverage %, Out of Pocket |
| Admissions | No, base only | Admission Rate |

```dax
Admissions = CALCULATE([Total Visits], visits[Is Admitted] = "Admitted")
```

### Collections and cost measures

| Measure | Shown as | Formula | Page |
|---|---|---|---|
| Coverage % | Coverage % | `DIVIDE([Insurance Covered], [Total Billed])` | Overview |
| Paid Amount | Paid Amount | `CALCULATE([Total Billed], visits[Payment Status] = "Paid")` | Revenue |
| Unpaid Amount | Unpaid Amount | `CALCULATE([Total Billed], visits[Payment Status] = "Pending")` | Overview, Revenue |
| Unpaid % | % Billing Unpaid | `DIVIDE([Unpaid Amount], [Total Billed])` | Overview, Revenue |
| Out of Pocket | Out of Pocket | `[Total Billed] - [Insurance Covered]` | Revenue |
| Out of Pocket % | Out-of-pocket % matrix | `DIVIDE([Out of Pocket], [Total Billed])` | Revenue |
| Avg Out-of-Pocket per Visit | Avg Out of Pocket per Visit | `DIVIDE([Out of Pocket], [Total Visits])` | Revenue |

### Operations measures

| Measure | Shown as | Formula | Page |
|---|---|---|---|
| Unique Patients | Unique Patients | Distinct count of patients | Overview |
| Admission Rate | Admission Rate | `DIVIDE([Admissions], [Total Visits])` | Overview, Operations |
| Emergency Visits | Emergency Visits | `CALCULATE([Total Visits], visits[Emergency Visit] = "Yes")` | Operations |
| Emergency % | Emergency % | `DIVIDE([Emergency Visits], [Total Visits])` | Operations |
| Avg Length of Stay | Avg Length of Stay | `AVERAGE(visits[Length of Stay])` | Operations |

### Patient experience measures

| Measure | Shown as | Formula | Page |
|---|---|---|---|
| Avg Satisfaction | Avg Satisfaction | `AVERAGE(visits[Patient Satisfaction Score])` | Overview, Experience |
| % Low Satisfaction | % Low Satisfaction | `DIVIDE(CALCULATE([Total Visits], visits[Patient Satisfaction Score] <= 4), [Total Visits])` | Overview, Experience |
| % High Satisfaction | % High Satisfaction | `DIVIDE(CALCULATE([Total Visits], visits[Patient Satisfaction Score] >= 8), [Total Visits])` | Overview, Experience |

The satisfaction score runs from 1 (worst) to 10 (best). An average alone hides the shape of the scores, so the report also shows the share of low (1–4) and high (8–10) scores.

---

## Key insights

**Revenue and collections**
- The hospital billed **$3.25M**. **$2.00M has been paid and $1.26M (38.68%) is unpaid**, so more than a third of revenue is at risk.
- **The unpaid problem is hospital-wide.** Unpaid % ranges only from 35.0% (Orthopedics) to 41.8% (Neurology) across departments, 38.0–40.1% across insurers, and 38.2–40.1% across service types. No single department, insurer or type of care is the cause.
- **Cardiology holds the most unpaid dollars ($0.35M)**, followed by General Surgery ($0.29M) and Orthopedics ($0.28M). They hold about 73% of unpaid billing because they produce about 73% of all billing.
- **Collections are unstable.** Unpaid billing was close to zero in May–Jun 2024, but in Aug 2024 and Mar 2025 the unpaid amount was higher than the paid amount, while visit volume stayed steady at about 300 a month.

**Patient cost burden**
- Insurance covers **66.35%** of billing ($2.16M). Patients paid **$1.09M out of pocket**, about **$225 per visit**.
- Patients pay **about 34% of every bill**, and this barely changes: 32.2% to 35.3% across every department and insurer combination.

**Operations and capacity**
- **4,860 visits from 4,833 unique patients**, so almost nobody returns. About half of visits have a follow-up date recorded, which suggests follow-ups are booked but not happening, or not being recorded as visits.
- The overall admission rate is **23.99%**. **Orthopedics (36.51%) and Neurology (30.73%)** admit the most patients, nearly three times Cardiology (13.21%).
- Average length of stay is **4.89 days** and barely changes by diagnosis (4.68–5.05 days), so bed demand depends on how many patients are admitted, not why.
- About **38.6% of visits are flagged as emergencies**, averaging about 144 a month.
- **Visits are spread evenly across the week.** Once the incomplete Oct 2024 – Jan 2025 period is excluded, every weekday has 510–530 visits.

**Patient experience**
- Average satisfaction is **3.8 out of 10**. **65% of visits scored 1–4** and only **17% scored 8–10**. Scores 1 and 2 alone account for more than half of all visits.
- **Cardiology (3.1) and General Surgery (3.0)** have the lowest satisfaction, well below Orthopedics (4.8), Pediatrics (4.4) and Neurology (4.4). Cardiology also holds the most unpaid billing and one of the highest unpaid rates.
- Satisfaction improved sharply during 2024: the average was about 1.5 in Jan–Jun 2024 and about 5.5 from Aug 2024 (visible by filtering Year-Month).

---

## Recommendations
1. **Fix the billing and claims process across the whole hospital.** The unpaid rate is similar everywhere, so targeting one department or insurer will not solve it.
2. **Track Unpaid % every month** and find out what went right in May–Jun 2024, when almost everything was paid, and what went wrong in Aug 2024 and Mar 2025.
3. **Start follow-up calls where the money is**: Cardiology, General Surgery and Orthopedics hold about 73% of unpaid dollars.
4. **Focus patient experience work on Cardiology and General Surgery**, and find out what changed in mid-2024 that lifted satisfaction, so it can be kept and extended.
5. **Plan bed capacity around Orthopedics and Neurology**, which have the highest admission rates.
6. **Review the follow-up process**, since about half of visits have a follow-up booked but almost no patients return.
7. **Fix data capture** for visit dates and the emergency flag, so future reporting can be trusted.

---

## Tools
Power BI Desktop · Power Query (M) · DAX

## How to open
1. Download [Healthcare_Data_Analysis.pbix](Healthcare_Data_Analysis.pbix).
2. Open it in Power BI Desktop.
3. Use the buttons on the left to move between pages and the slicers to filter.

## Author
**Kavish Sharma**
