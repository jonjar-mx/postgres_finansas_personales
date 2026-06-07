# PostgreSQL Data Specification - Finanzas Personales

## Purpose

Define the PostgreSQL schema required to persist user finance data currently stored in the React frontend through `localStorage`.

The database must support:

- Users.
- Budget categories.
- Monthly budgets by category.
- Transactions by category and date.
- Future extension for multiple accounts or currencies.

## Assumptions

- The first backend version will support authenticated users, even if the frontend starts with a single local user flow.
- Amounts are stored as decimal values, not floats.
- Budget periods are monthly.
- Transactions are expenses by default. Income support can be added later with a transaction type.
- All timestamps are stored in UTC.

## Entity Model

### users

Stores application users.

```sql
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT NOT NULL UNIQUE,
  display_name TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

### categories

Stores reusable finance categories owned by a user.

```sql
CREATE TABLE categories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  color TEXT,
  icon TEXT,
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_id, name)
);
```

### budgets

Stores monthly budget targets per category.

```sql
CREATE TABLE budgets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  category_id UUID NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
  month DATE NOT NULL,
  amount NUMERIC(12, 2) NOT NULL CHECK (amount >= 0),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_id, category_id, month),
  CHECK (date_trunc('month', month)::date = month)
);
```

`month` must always be the first day of the month, for example `2026-06-01`.

### transactions

Stores user transactions.

```sql
CREATE TABLE transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  category_id UUID NOT NULL REFERENCES categories(id) ON DELETE RESTRICT,
  transaction_date DATE NOT NULL,
  description TEXT NOT NULL,
  amount NUMERIC(12, 2) NOT NULL CHECK (amount > 0),
  type TEXT NOT NULL DEFAULT 'expense' CHECK (type IN ('expense', 'income')),
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

## Required Extensions

```sql
CREATE EXTENSION IF NOT EXISTS pgcrypto;
```

## Indexes

```sql
CREATE INDEX idx_categories_user_id ON categories(user_id);
CREATE INDEX idx_budgets_user_month ON budgets(user_id, month);
CREATE INDEX idx_budgets_user_category ON budgets(user_id, category_id);
CREATE INDEX idx_transactions_user_date ON transactions(user_id, transaction_date DESC);
CREATE INDEX idx_transactions_user_category_date ON transactions(user_id, category_id, transaction_date DESC);
```

## Derived Dashboard Query

The backend can calculate dashboard progress with a query like this:

```sql
SELECT
  b.id AS budget_id,
  c.id AS category_id,
  c.name AS category,
  b.month,
  b.amount AS budget_amount,
  COALESCE(SUM(t.amount) FILTER (WHERE t.type = 'expense'), 0) AS spent,
  b.amount - COALESCE(SUM(t.amount) FILTER (WHERE t.type = 'expense'), 0) AS remaining,
  CASE
    WHEN b.amount = 0 THEN 0
    ELSE COALESCE(SUM(t.amount) FILTER (WHERE t.type = 'expense'), 0) / b.amount * 100
  END AS progress
FROM budgets b
JOIN categories c ON c.id = b.category_id
LEFT JOIN transactions t
  ON t.user_id = b.user_id
  AND t.category_id = b.category_id
  AND date_trunc('month', t.transaction_date)::date = b.month
WHERE b.user_id = $1
  AND b.month = $2
GROUP BY b.id, c.id, c.name, b.month, b.amount
ORDER BY c.sort_order, c.name;
```

## Seed Data

For a new user, create these categories:

```text
Housing
Food
Transportation
Utilities
Health
Entertainment
Savings
```

Optional development seed budgets for `2026-06-01`:

```text
Housing: 1200.00
Food: 450.00
Transportation: 180.00
Utilities: 240.00
Entertainment: 150.00
Savings: 500.00
```

Optional development seed transactions:

```text
2026-06-01 | Housing | Rent payment | 1200.00
2026-06-02 | Food | Groceries | 86.35
2026-06-03 | Transportation | Metro card recharge | 40.00
2026-06-04 | Utilities | Electric bill | 96.12
2026-06-04 | Entertainment | Streaming services | 27.98
```

## Migration Order

1. Enable `pgcrypto`.
2. Create `users`.
3. Create `categories`.
4. Create `budgets`.
5. Create `transactions`.
6. Create indexes.
7. Add seed data for development.

## Data Validation Rules

- Category names are required and unique per user.
- Budget amount must be zero or greater.
- Transaction amount must be greater than zero.
- Budget month must be normalized to the first day of the month.
- Transaction dates must be valid calendar dates.
- A transaction cannot reference a category from another user.
- A budget cannot reference a category from another user.

## Open Decisions

- Authentication provider: local auth, Supabase Auth, Auth0, Clerk, or another provider.
- Whether income should be included in dashboard totals immediately or later.
- Whether users can archive categories that have historical transactions.
- Whether multi-currency support is required.
