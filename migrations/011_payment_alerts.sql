CREATE TABLE IF NOT EXISTS payment_alerts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  account_id UUID,
  title TEXT NOT NULL,
  description TEXT,
  alert_type TEXT NOT NULL DEFAULT 'payment' CHECK (alert_type IN ('payment', 'card_cutoff', 'service', 'budget')),
  due_date DATE NOT NULL,
  amount NUMERIC(12, 2) CHECK (amount IS NULL OR amount >= 0),
  is_paid BOOLEAN NOT NULL DEFAULT false,
  is_recurring BOOLEAN NOT NULL DEFAULT false,
  recurrence TEXT CHECK (recurrence IS NULL OR recurrence IN ('weekly', 'monthly', 'yearly')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_id, id),
  CONSTRAINT payment_alerts_account_fkey
    FOREIGN KEY (user_id, account_id)
    REFERENCES accounts(user_id, id)
    ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_payment_alerts_user_due_date ON payment_alerts(user_id, due_date);
CREATE INDEX IF NOT EXISTS idx_payment_alerts_user_paid_due_date ON payment_alerts(user_id, is_paid, due_date);

DROP TRIGGER IF EXISTS trg_payment_alerts_set_updated_at ON payment_alerts;
CREATE TRIGGER trg_payment_alerts_set_updated_at
BEFORE UPDATE ON payment_alerts
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();
