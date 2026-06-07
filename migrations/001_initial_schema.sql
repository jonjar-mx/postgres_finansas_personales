CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT NOT NULL UNIQUE,
  display_name TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE categories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  color TEXT,
  icon TEXT,
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_id, id),
  UNIQUE (user_id, name)
);

CREATE TABLE budgets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  category_id UUID NOT NULL,
  month DATE NOT NULL,
  amount NUMERIC(12, 2) NOT NULL CHECK (amount >= 0),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_id, category_id, month),
  CHECK (date_trunc('month', month)::date = month),
  FOREIGN KEY (user_id, category_id)
    REFERENCES categories(user_id, id)
    ON DELETE CASCADE
);

CREATE TABLE accounts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  business_name TEXT,
  address TEXT,
  phone TEXT,
  email TEXT,
  is_own BOOLEAN NOT NULL DEFAULT false,
  is_credit BOOLEAN NOT NULL DEFAULT false,
  credit_limit NUMERIC(12, 2) NOT NULL DEFAULT 0 CHECK (credit_limit >= 0),
  account_type TEXT NOT NULL DEFAULT 'bank' CHECK (account_type IN ('cash', 'bank', 'credit_card', 'loan', 'investment', 'external')),
  is_liquid BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_id, id),
  UNIQUE (user_id, name)
);

CREATE TABLE transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  transaction_date DATE NOT NULL,
  paid_by_account_id UUID,
  paid_to_account_id UUID,
  paid_by TEXT NOT NULL,
  paid_to TEXT NOT NULL,
  ticket_code TEXT,
  ticket_link TEXT,
  currency TEXT NOT NULL DEFAULT '$MX',
  transaction_type TEXT NOT NULL DEFAULT 'expense' CHECK (transaction_type IN ('expense', 'income', 'transfer', 'credit_payment')),
  total_amount NUMERIC(12, 2) NOT NULL DEFAULT 0,
  notes TEXT,
  created_by_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  updated_by_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  deleted BOOLEAN NOT NULL DEFAULT false,
  deleted_at TIMESTAMPTZ,
  deleted_by_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_id, id),
  CONSTRAINT transactions_paid_by_account_fkey
    FOREIGN KEY (user_id, paid_by_account_id)
    REFERENCES accounts(user_id, id)
    ON DELETE RESTRICT,
  CONSTRAINT transactions_paid_to_account_fkey
    FOREIGN KEY (user_id, paid_to_account_id)
    REFERENCES accounts(user_id, id)
    ON DELETE RESTRICT
);

CREATE TABLE transaction_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  transaction_id UUID NOT NULL,
  category_id UUID NOT NULL,
  item TEXT NOT NULL,
  units NUMERIC(18, 6) NOT NULL CHECK (units <> 0),
  unit_price NUMERIC(12, 2) NOT NULL,
  total_price NUMERIC(12, 2) NOT NULL CHECK (total_price <> 0),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  FOREIGN KEY (user_id, transaction_id)
    REFERENCES transactions(user_id, id)
    ON DELETE CASCADE,
  FOREIGN KEY (user_id, category_id)
    REFERENCES categories(user_id, id)
    ON DELETE RESTRICT
);

CREATE INDEX idx_categories_user_id ON categories(user_id);
CREATE INDEX idx_budgets_user_month ON budgets(user_id, month);
CREATE INDEX idx_budgets_user_category ON budgets(user_id, category_id);
CREATE INDEX idx_accounts_user_name ON accounts(user_id, name);
CREATE INDEX idx_transactions_user_date ON transactions(user_id, transaction_date DESC);
CREATE INDEX idx_transactions_user_deleted_date ON transactions(user_id, deleted, transaction_date DESC);
CREATE INDEX idx_transaction_items_user_transaction ON transaction_items(user_id, transaction_id);
CREATE INDEX idx_transaction_items_user_category ON transaction_items(user_id, category_id);

CREATE TRIGGER trg_users_set_updated_at
BEFORE UPDATE ON users
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_categories_set_updated_at
BEFORE UPDATE ON categories
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_budgets_set_updated_at
BEFORE UPDATE ON budgets
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_accounts_set_updated_at
BEFORE UPDATE ON accounts
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_transactions_set_updated_at
BEFORE UPDATE ON transactions
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_transaction_items_set_updated_at
BEFORE UPDATE ON transaction_items
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();
