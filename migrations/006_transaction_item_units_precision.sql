ALTER TABLE transaction_items
  ALTER COLUMN units TYPE NUMERIC(18, 6)
  USING units::NUMERIC(18, 6);
