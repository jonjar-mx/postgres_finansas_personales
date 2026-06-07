ALTER TABLE transactions
  ADD COLUMN IF NOT EXISTS transaction_type TEXT NOT NULL DEFAULT 'expense';

UPDATE transactions t
SET transaction_type = CASE
    WHEN paid_by_account.is_own = true
      AND paid_to_account.is_own = true
      AND paid_to_account.account_type IN ('credit_card', 'loan')
      THEN 'credit_payment'
    WHEN paid_by_account.is_own = true
      AND paid_to_account.is_own = true
      THEN 'transfer'
    WHEN paid_to_account.is_own = true
      AND COALESCE(paid_by_account.is_own, false) = false
      THEN 'income'
    ELSE 'expense'
  END
FROM accounts paid_by_account,
     accounts paid_to_account
WHERE paid_by_account.user_id = t.user_id
  AND paid_by_account.id = t.paid_by_account_id
  AND paid_to_account.user_id = t.user_id
  AND paid_to_account.id = t.paid_to_account_id
  AND t.transaction_type = 'expense';

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'transactions_transaction_type_check'
  ) THEN
    ALTER TABLE transactions
      ADD CONSTRAINT transactions_transaction_type_check
      CHECK (transaction_type IN ('expense', 'income', 'transfer', 'credit_payment'));
  END IF;
END;
$$;
