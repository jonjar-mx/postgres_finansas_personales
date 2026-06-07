ALTER TABLE transactions
  ADD COLUMN IF NOT EXISTS created_by_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS updated_by_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS deleted BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS deleted_by_user_id UUID REFERENCES users(id) ON DELETE SET NULL;

UPDATE transactions
SET created_by_user_id = COALESCE(created_by_user_id, user_id),
    updated_by_user_id = COALESCE(updated_by_user_id, user_id)
WHERE created_by_user_id IS NULL OR updated_by_user_id IS NULL;

CREATE INDEX IF NOT EXISTS idx_transactions_user_deleted_date
  ON transactions(user_id, deleted, transaction_date DESC);
