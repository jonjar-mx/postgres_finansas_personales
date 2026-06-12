CREATE TABLE IF NOT EXISTS account_members (
  account_id UUID NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  role TEXT NOT NULL CHECK (role IN ('owner', 'admin', 'expender', 'reader')),
  created_by_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (account_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_account_members_user_role
  ON account_members(user_id, role);

CREATE INDEX IF NOT EXISTS idx_account_members_account_role
  ON account_members(account_id, role);

DROP TRIGGER IF EXISTS trg_account_members_set_updated_at ON account_members;
CREATE TRIGGER trg_account_members_set_updated_at
BEFORE UPDATE ON account_members
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

INSERT INTO account_members (account_id, user_id, role, created_by_user_id)
SELECT id, user_id, 'owner', user_id
FROM accounts
ON CONFLICT (account_id, user_id) DO UPDATE
  SET role = 'owner';
