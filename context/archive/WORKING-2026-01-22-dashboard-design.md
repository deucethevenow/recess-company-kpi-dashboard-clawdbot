# Session Handoff: Company KPI Dashboard Design

**Date:** 2026-01-22
**Phase:** Brainstorming / Requirements Gathering

---

## 🎯 Mission

Design and build a unified company dashboard that:
1. Gives each person ONE metric they own
2. Automates data from HubSpot, BigQuery, Sheets
3. Replaces manual Asana goal updates
4. Is secure (not public web)
5. Is prescriptive for non-analytical users

---

## ✅ Completed This Session

### Departments Captured (5 of 10):

1. **Supply (Ian Hong)** - ✅ Full metrics captured
   - Owned metric: New Unique Inventory Added
   - Key problem: Top-of-funnel lead inventory
   - Data sources: HubSpot, Sheets, Smart Lead

2. **Demand Account Mgmt (Char's team)** - ✅ Full metrics captured
   - Already has "one metric per owner" model
   - KPI scorecard with weekly tracking
   - Contract spend tracking

3. **Demand Sales (Andy's team)** - ✅ Full metrics captured
   - Andy owns NRR
   - Danny/Katie own Pipeline Coverage
   - AI deal scoring already in place

4. **Marketing** - ✅ Full metrics captured
   - Owned metric: Marketing-Influenced Pipeline (FT+LT)/2
   - Attribution: 50% credit each for First Touch & Last Touch
   - Action item: Query BigQuery for historical baseline

5. **Accounting/Finance** - ✅ Full metrics captured (DUAL DASHBOARDS)
   - **Operations Dashboard:** Invoice collection rate, bill status by Bill.com stage, W-9 compliance, QBO/Platform reconciliation
   - **CFO Dashboard:** Runway, cash, concentration risk, NRR, customer segmentation
   - Key insight: 41% revenue from one customer = existential risk

### SQL Queries Documented:
- Sales Manager Quota & Pipeline Coverage
- Net Revenue Retention Tracker
- Funnel Math Calculator (proposed)
- QBO to Platform Invoice Reconciliation (Delta should = 0)

### Key Decisions Made:
- North Star: Revenue (not GMV)
- Sales Leader metric: NRR
- Seller metric: Weighted Pipeline Coverage (3x target)
- Dashboard style: Prescriptive with traffic lights
- Marketing attribution: (FT + LT) / 2
- Accounting needs TWO dashboards (Operations + CFO)

---

## ⏳ TODO - Next Session

### Remaining Departments to Gather:
- [x] Marketing (1 person) - ✅ Completed
- [x] Accounting/Finance (1 person) - ✅ Completed
- [ ] Supply Account Mgmt (1 person) - **NEXT**
- [ ] Engineering/Product (4 people)
- [ ] AI Automations (1 person)
- [ ] CEO/Business Dev (Jack)

### Design Work Needed:
- [ ] Technology stack decision
- [ ] Security approach
- [ ] Metric ownership matrix (all 18 people)
- [ ] Implementation plan

### Action Items:
- [ ] Query BigQuery for historical marketing-influenced revenue %

---

## 📁 Key Files

- **Full Brainstorm:** `context/plans/2026-01-22-dashboard-brainstorm.md`
- **SQL Queries:** In brainstorm doc (to be moved to `queries/` folder)

---

## 🚀 To Continue

Start new session with:
```
I'm continuing work on the company KPI dashboard.
Read context/WORKING-2026-01-22-dashboard-design.md and
context/plans/2026-01-22-dashboard-brainstorm.md to pick up where we left off.
```

Or use: `/orient`
