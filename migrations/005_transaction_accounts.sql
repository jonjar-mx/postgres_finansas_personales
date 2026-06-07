CREATE TABLE IF NOT EXISTS accounts (
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
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_id, id),
  UNIQUE (user_id, name)
);

CREATE INDEX IF NOT EXISTS idx_accounts_user_name ON accounts(user_id, name);

DROP TRIGGER IF EXISTS trg_accounts_set_updated_at ON accounts;
CREATE TRIGGER trg_accounts_set_updated_at
BEFORE UPDATE ON accounts
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

ALTER TABLE transactions
  ADD COLUMN IF NOT EXISTS paid_by_account_id UUID,
  ADD COLUMN IF NOT EXISTS paid_to_account_id UUID;

INSERT INTO accounts (user_id, name)
SELECT DISTINCT user_id, paid_by
FROM transactions
WHERE paid_by IS NOT NULL AND btrim(paid_by) <> ''
ON CONFLICT (user_id, name) DO NOTHING;

INSERT INTO accounts (user_id, name)
SELECT DISTINCT user_id, paid_to
FROM transactions
WHERE paid_to IS NOT NULL AND btrim(paid_to) <> ''
ON CONFLICT (user_id, name) DO NOTHING;

UPDATE transactions t
SET paid_by_account_id = a.id
FROM accounts a
WHERE a.user_id = t.user_id
  AND a.name = t.paid_by
  AND t.paid_by_account_id IS NULL;

UPDATE transactions t
SET paid_to_account_id = a.id
FROM accounts a
WHERE a.user_id = t.user_id
  AND a.name = t.paid_to
  AND t.paid_to_account_id IS NULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'transactions_paid_by_account_fkey'
  ) THEN
    ALTER TABLE transactions
      ADD CONSTRAINT transactions_paid_by_account_fkey
      FOREIGN KEY (user_id, paid_by_account_id)
      REFERENCES accounts(user_id, id)
      ON DELETE RESTRICT;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'transactions_paid_to_account_fkey'
  ) THEN
    ALTER TABLE transactions
      ADD CONSTRAINT transactions_paid_to_account_fkey
      FOREIGN KEY (user_id, paid_to_account_id)
      REFERENCES accounts(user_id, id)
      ON DELETE RESTRICT;
  END IF;
END;
$$;
