# PRICE-24 Homepage Metrics Design

## Context

Homepage cards must be filtered by `customer_access` and compare the latest
snapshot (`A`) vs previous snapshot (`B`) per `(product_id, supplier_id)`.
Movement metrics and top movers must exclude unchanged products (`A == B`).

## Data model decision

Use a hybrid write/read model:

- Keep Mongo `prices` as full event history.
- Add Postgres `product_price_snapshots` for deterministic and indexed `A/B`
  access patterns needed by dashboard queries.
- Continue writing snapshots through the existing ingestion path
  (`Marketplaces.record_product_price/2`) so no direct ad-hoc DB writes bypass
  the admin pipeline.

## Canonical tables and joins

- `products`: product metadata (name, image, category, supplier_name).
- `product_price_snapshots`: price observations (`product_id`, `supplier_id`,
  `price`, `scraped_at`).
- `users_suppliers`: access scope (`user_id` -> allowed `supplier_id`).

Access filter:

- Admin: all products.
- Non-admin: `products.supplier_id IN users_suppliers(user_id)` universe.

## Latest/previous selection strategy

Pair selection uses a window:

- partition by `(product_id, supplier_id)`
- order by `scraped_at DESC, id DESC`
- `row_number = 1` => `A` (latest), `row_number = 2` => `B` (previous)

Rules:

- missing `B` => excluded from movement cards/counts
- `A == B` => excluded from movement cards/counts
- inventory totals still include those products

## Index plan

### Postgres

- `product_price_snapshots(product_id, supplier_id, scraped_at, id)` as
  `product_price_snapshots_pair_scraped_at_id_idx`
- `product_price_snapshots(scraped_at, product_id, supplier_id)` as
  `product_price_snapshots_scraped_at_product_supplier_idx`
- `products(supplier_id)`
- `users_suppliers(supplier_id, user_id)` (unique `(user_id, supplier_id)`
  already exists)

### Mongo

- `prices(product_id, timestamp DESC)`
- `prices(timestamp DESC)`

## Query shape used in app

Implemented in `Marketplaces.get_homepage_metrics/1`:

- total products visible to user
- products scraped in last 24h
- products with increase/decrease in last 24h
- top increase/decrease card payload:
  - product name/image
  - current price
  - absolute and percentage delta
  - supplier/category chips
- `as_of` timestamp

## Materialization decision

Start in query-first mode (current implementation) and trigger materialization
when one or more conditions hold:

- homepage metrics endpoint p95 > 400ms for 3 consecutive windows
- a single metrics query > 200ms under normal load
- planner repeatedly falls back to sequential scans on snapshots
- DB CPU > 70% during peak traffic due to this endpoint
- high result reuse with fixed daily scrape cadence

If triggered:

- materialize daily summary after scrape completion
- expose `as_of` and stale marker when freshness exceeds SLA
- keep unchanged-product exclusion semantics identical

## Explain analyze

`EXPLAIN ANALYZE` snapshots were not collected in this sandbox because no
representative staging dataset is available in the current run environment.
Runbook for final validation:

1. deploy migration
2. backfill / warm snapshots
3. capture before/after plans for movement and top-mover queries
4. record p50/p95/p99 and rows scanned vs returned
