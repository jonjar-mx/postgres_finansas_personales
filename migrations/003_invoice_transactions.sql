ALTER TABLE transactions
  ADD COLUMN IF NOT EXISTS paid_by TEXT,
  ADD COLUMN IF NOT EXISTS paid_to TEXT,
  ADD COLUMN IF NOT EXISTS ticket_code TEXT,
  ADD COLUMN IF NOT EXISTS ticket_link TEXT,
  ADD COLUMN IF NOT EXISTS currency TEXT NOT NULL DEFAULT '$MX',
  ADD COLUMN IF NOT EXISTS total_amount NUMERIC(12, 2) NOT NULL DEFAULT 0;


DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'transactions_user_id_id_key'
  ) THEN
    ALTER TABLE transactions ADD CONSTRAINT transactions_user_id_id_key UNIQUE (user_id, id);
  END IF;
END;
$$;

CREATE TABLE IF NOT EXISTS transaction_items (
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

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_name = 'transactions' AND column_name = 'category_id'
  ) THEN
    EXECUTE $migrate_old_transactions$
      INSERT INTO transaction_items (user_id, transaction_id, category_id, item, units, unit_price, total_price, created_at, updated_at)
      SELECT user_id, id, category_id, description, 1, amount, amount, created_at, updated_at
      FROM transactions t
      WHERE NOT EXISTS (
        SELECT 1 FROM transaction_items ti WHERE ti.user_id = t.user_id AND ti.transaction_id = t.id
      )
    $migrate_old_transactions$;

    EXECUTE $fill_invoice_columns$
      UPDATE transactions
      SET paid_by = COALESCE(paid_by, CASE WHEN type = 'income' THEN 'income' ELSE 'cash' END),
          paid_to = COALESCE(paid_to, description),
          ticket_code = COALESCE(ticket_code, id::text),
          total_amount = CASE
            WHEN total_amount = 0 THEN COALESCE(amount, total_amount)
            ELSE total_amount
          END
      WHERE paid_by IS NULL OR paid_to IS NULL OR ticket_code IS NULL OR total_amount = 0
    $fill_invoice_columns$;

    ALTER TABLE transactions
      DROP COLUMN IF EXISTS category_id,
      DROP COLUMN IF EXISTS description,
      DROP COLUMN IF EXISTS amount,
      DROP COLUMN IF EXISTS type;
  END IF;
END;
$$;

UPDATE transactions
SET paid_by = COALESCE(paid_by, 'cash'),
    paid_to = COALESCE(paid_to, 'unknown'),
    ticket_code = COALESCE(ticket_code, id::text)
WHERE paid_by IS NULL OR paid_to IS NULL OR ticket_code IS NULL;

ALTER TABLE transactions
  ALTER COLUMN paid_by SET NOT NULL,
  ALTER COLUMN paid_to SET NOT NULL;

CREATE INDEX IF NOT EXISTS idx_transaction_items_user_transaction ON transaction_items(user_id, transaction_id);
CREATE INDEX IF NOT EXISTS idx_transaction_items_user_category ON transaction_items(user_id, category_id);
DROP INDEX IF EXISTS idx_transactions_user_category_date;

DROP TRIGGER IF EXISTS trg_transaction_items_set_updated_at ON transaction_items;
CREATE TRIGGER trg_transaction_items_set_updated_at
BEFORE UPDATE ON transaction_items
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();
