---
name: bigquery-query-agent
description: Read-only BigQuery query agent for Recess. Use when you need to explore or answer business questions with SELECT-only SQL against the Recess BigQuery warehouse, generate safe queries, validate results, or follow KPI-view best practices and mandatory filters.
---

# BigQuery Query Agent (Recess)

## Quick start
- Use the `mcp__bigquery__query` tool for execution.
- Only SELECT queries; always add `LIMIT` on exploratory queries.
- Prefer authoritative KPI views first (see references).

## Workflow
1) Identify the data need (entity + metric).
2) Use authoritative views if available.
3) Apply mandatory filters/gotchas.
4) Run query via `mcp__bigquery__query`.
5) Validate results (row counts, NULLs, totals).

## Reference
Load **references/bigquery-guide.md** for:
- Dataset quick lookup
- Authoritative sources
- Mandatory filters / gotchas
- Query examples and tool usage
