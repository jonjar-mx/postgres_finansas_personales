ALTER TABLE accounts
  ADD COLUMN IF NOT EXISTS account_type TEXT NOT NULL DEFAULT 'bank',
  ADD COLUMN IF NOT EXISTS is_liquid BOOLEAN NOT NULL DEFAULT true;

UPDATE accounts
SET account_type = CASE
    WHEN is_credit THEN 'credit_card'
    WHEN is_own THEN 'bank'
    ELSE 'external'
  END,
  is_liquid = CASE
    WHEN is_credit THEN false
    WHEN is_own THEN true
    ELSE false
  END
WHERE account_type = 'bank'
  AND (is_credit OR NOT is_own);

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'accounts_account_type_check'
  ) THEN
    ALTER TABLE accounts
      ADD CONSTRAINT accounts_account_type_check
      CHECK (account_type IN ('cash', 'bank', 'credit_card', 'loan', 'investment', 'external'));
  END IF;
END;
$$;
