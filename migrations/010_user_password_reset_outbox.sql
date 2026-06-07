CREATE TABLE IF NOT EXISTS password_reset_emails (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  email TEXT NOT NULL,
  subject TEXT NOT NULL,
  body TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'queued' CHECK (status IN ('queued', 'pending', 'sent', 'failed')),
  error TEXT,
  sent_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_password_reset_emails_user_created
  ON password_reset_emails(user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_password_reset_emails_status_created
  ON password_reset_emails(status, created_at DESC);

DROP TRIGGER IF EXISTS trg_password_reset_emails_set_updated_at ON password_reset_emails;
CREATE TRIGGER trg_password_reset_emails_set_updated_at
BEFORE UPDATE ON password_reset_emails
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();
