ALTER TABLE users
  ADD COLUMN IF NOT EXISTS plan_tier TEXT NOT NULL DEFAULT 'free',
  ADD COLUMN IF NOT EXISTS plan_changed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  ADD COLUMN IF NOT EXISTS free_grace_started_at TIMESTAMPTZ;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'users_plan_tier_check'
  ) THEN
    ALTER TABLE users
      ADD CONSTRAINT users_plan_tier_check CHECK (plan_tier IN ('free', 'individual', 'family'));
  END IF;
END $$;

UPDATE users
SET free_grace_started_at = COALESCE(free_grace_started_at, plan_changed_at, created_at)
WHERE plan_tier = 'free';

CREATE INDEX IF NOT EXISTS idx_users_plan_tier_grace
  ON users(plan_tier, free_grace_started_at);

CREATE INDEX IF NOT EXISTS idx_transactions_user_transaction_date
  ON transactions(user_id, transaction_date);
