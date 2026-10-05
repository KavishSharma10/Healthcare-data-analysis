# Hospital Performance Dashboard (Power BI)

An interactive three-page Power BI report that helps hospital management answer one question: **where is money and capacity leaking, and which departments need attention first?**

It tracks patient volume, billing and collections, insurance coverage, admissions, emergency demand and patient satisfaction. Every page can be filtered by Year-Month, Department, Service Type and Insurance Provider.

---

## Business problem

The hospital bills well but collects slowly, and operational pressure is spread unevenly across departments. Leadership needs one view that shows:

1. **Revenue at risk**: how much billing is still unpaid, and in which departments and with which insurers.
2. **Patient cost burden**: how much of each bill insurance covers and how much patients pay themselves.
3. **Operational load**: emergency share, admission rates and length of stay by department and diagnosis, and the busiest days of the week.
4. **Patient experience**: average satisfaction score.

---

## Report pages

### 1. Executive Overview
KPI cards for Total Visits, Unique Patients, Total Billed, Coverage %, Unpaid Amount, % Billing Unpaid, Admission Rate and Avg Satisfaction. Below them: Total Billed vs Pending Amount by department, the monthly trend of visits and billing, and the visit mix by service type.

### 2. Revenue & Collections
Pending amount by department, total billed split into paid and pending, pending amount by insurance provider, and an out-of-pocket cost matrix (department × insurer) with heat-map shading.

### 3. Operations & Capacity
KPI cards for Emergency Visits, Emergency %, Admission Rate and Avg Length of Stay. Below them: emergency visits by month with an average line, admission rate by department, average length of stay by diagnosis, and total visits by day of the week.

Each page has the same left panel with slicers and navigation buttons (OverView, Revenue, Operations).

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

The calendar ends on 31 May 2025, and a report-level filter excludes 2025-05 from all pages.

---

## DAX measures

All measures are in the `_Measures_data_values` table. Definitions are in [`dax/measures.dax`](dax/measures.dax).

### Base measures
These are the building blocks. Admissions and Insurance Covered are not shown on any visual themselves; they are computed because other measures use their output.

| Measure | Used on dashboard? | Feeds into |
|---|---|---|
| Total Visits | Yes (KPI card, trend, donut, day-of-week chart) | Admissions, Admission Rate, Emergency Visits, Emergency % |
| Total Billed | Yes (KPI card, bar charts, trend, donut) | Coverage %, Out of Pocket, Pending Amount, Pending $ % |
| Insurance Covered | No, base only | Coverage %, Out of Pocket |
| Admissions | No, base only | Admission Rate |

```dax
Admissions = CALCULATE([Total Visits], visits[Is Admitted] = "Admitted")
```

### Measures shown on the dashboard

| Measure | Shown as | Formula | Page |
|---|---|---|---|
| Unique Patients | Unique Patients | Distinct count of patients | Overview |
| Coverage % | Coverage % | `DIVIDE([Insurance Covered], [Total Billed])` | Overview |
| Pending Amount | Unpaid Amount | `CALCULATE([Total Billed], visits[Payment Status] = "Pending")` | Overview, Revenue |
| Pending $ % | % Billing Unpaid | `DIVIDE([Pending Amount], [Total Billed])` | Overview |
| Out of Pocket | Out-of-pocket matrix | `[Total Billed] - [Insurance Covered]` | Revenue |
| Admission Rate | Admission Rate | `DIVIDE([Admissions], [Total Visits])` | Overview, Operations |
| Emergency Visits | Emergency Visits | `CALCULATE([Total Visits], visits[Emergency Visit] = "Yes")` | Operations |
| Emergency % | Emergency % | `DIVIDE([Emergency Visits], [Total Visits])` | Operations |
| Avg Length of Stay | Avg Length of Stay | `AVERAGE(visits[Length of Stay])` | Operations |
| Avg Satisfaction | Avg Satisfaction | `AVERAGE(visits[Patient Satisfaction Score])` | Overview |

Pending Amount is also a base for Pending $ %, and Emergency Visits is a base for Emergency %. Each is computed once and reused.

---

## Key insights

**Revenue and collections**
- The hospital billed **$3.25M**. Insurance covers **66.35%** of it.
- **$1.26M (38.68%) is still unpaid**, so more than a third of revenue is at risk.
- **Cardiology** has the most unpaid billing ($345K), followed by General Surgery ($291K) and Orthopedics ($278K). These three hold about 73% of all pending money.
- Unpaid amounts are almost even across insurers (Allianz $0.43M, AXA $0.42M, Aviva $0.41M). This points to a collections-process problem inside departments rather than one slow insurer.
- Patients paid **$1.09M out of pocket**. Orthopedics ($274K) and Cardiology ($270K) put the biggest cost burden on patients.

**Operations and capacity**
- **4,860 visits** from **4,833 unique patients**, so almost every patient visited once and follow-up activity is very low.
- Outpatient visits make up about **51%** of volume, with inpatient and emergency at about 25% each.
- **Orthopedics** has the highest admission rate (36.51%), more than double Cardiology (13.21%), even though Cardiology bills the most.
- Average length of stay is **4.89 days** and varies little by diagnosis (Fracture 5.05 days, Migraine 4.68 days).
- **Wednesday to Saturday** are the busiest days (750–760 visits each), about 24% more than Monday, Tuesday and Sunday (610–615). Staffing can be shifted towards the late week.

**Patient experience**
- Average satisfaction is **3.8 out of 5**.

---

## Recommendations
1. Focus collections follow-up on Cardiology, General Surgery and Orthopedics first; together they hold most of the unpaid $1.26M.
2. Review the billing and claims workflow inside these departments, since the problem is not tied to one insurer.
3. Plan bed capacity in Orthopedics and Neurology around their higher admission rates.
4. Roster more staff from Wednesday to Saturday.

---

## Tools
Power BI Desktop · Power Query (M) · DAX

## How to open
1. Download [Healthcare_Data_Analysis.pbix](Healthcare_Data_Analysis.pbix).
2. Open it in [Power BI Desktop](https://www.microsoft.com/power-bi/desktop).
3. Use the buttons on the left to move between pages and the slicers to filter.

## Author
**Kavish Sharma**
