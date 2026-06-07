ALTER TABLE users
  ADD COLUMN IF NOT EXISTS password_hash TEXT;

UPDATE users
SET password_hash = 'pbkdf2_sha256$210000$yWWKOHcyVACpovsrgv5Fww$DU8i3y_ulk3Z9dRUQ3TUsc8N0Tm5uJMJi_GaRIfD2TY'
WHERE email = 'demo@finanzas.local'
  AND password_hash IS NULL;
