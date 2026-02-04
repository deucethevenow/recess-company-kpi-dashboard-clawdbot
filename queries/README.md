# SQL Queries

## Organization

Queries are organized by KPI category:

```
queries/
├── revenue/          # Revenue and financial KPIs
├── customers/        # Customer metrics and health
├── operations/       # Operational performance
├── sales/            # Sales pipeline and conversion
└── README.md         # This file
```

## Naming Convention

Use descriptive names with date prefix for versioning:
- `YYYY-MM-DD-metric-name.sql`
- Example: `2025-01-22-monthly-recurring-revenue.sql`

## Query Template

```sql
-- KPI: [Name]
-- Description: [What this measures]
-- Owner: [Team/Person]
-- Refresh: [Frequency]
-- Last Updated: [Date]

-- Query starts here
SELECT
    ...
FROM
    ...
WHERE
    ...
```

## Best Practices

1. **Comment your queries** - Explain complex logic
2. **Use CTEs** - Break down complex queries for readability
3. **Parameterize dates** - Make queries reusable
4. **Test with limits** - Use LIMIT during development
5. **Version control** - Track changes in git
