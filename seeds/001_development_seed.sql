WITH inserted_user AS (
  INSERT INTO users (email, display_name, password_hash, role, status)
  VALUES ('demo@finanzas.local', 'Demo User', 'pbkdf2_sha256$210000$Cy6WxqDrlKpcXh74Xl2IsQ$3tLbTsS0bhJEZZFlmJuuhmqjHsVoGkWz4GPceanm9kM', 'admin', 'active')
  ON CONFLICT (email) DO UPDATE
    SET display_name = EXCLUDED.display_name,
        password_hash = COALESCE(users.password_hash, EXCLUDED.password_hash),
        role = 'admin',
        status = 'active'
  RETURNING id
),
category_seed (name, color, icon, sort_order) AS (
  VALUES
    ('Housing', '#2563eb', 'home', 10),
    ('Food', '#16a34a', 'utensils', 20),
    ('Transportation', '#ca8a04', 'car', 30),
    ('Utilities', '#0891b2', 'bolt', 40),
    ('Health', '#dc2626', 'heart-pulse', 50),
    ('Entertainment', '#9333ea', 'film', 60),
    ('Savings', '#0f766e', 'piggy-bank', 70)
),
inserted_categories AS (
  INSERT INTO categories (user_id, name, color, icon, sort_order)
  SELECT inserted_user.id, category_seed.name, category_seed.color, category_seed.icon, category_seed.sort_order
  FROM inserted_user
  CROSS JOIN category_seed
  ON CONFLICT (user_id, name) DO UPDATE
    SET color = EXCLUDED.color,
        icon = EXCLUDED.icon,
        sort_order = EXCLUDED.sort_order
  RETURNING id, user_id, name
),
budget_seed (category_name, amount) AS (
  VALUES
    ('Housing', 1200.00),
    ('Food', 450.00),
    ('Transportation', 180.00),
    ('Utilities', 240.00),
    ('Entertainment', 150.00),
    ('Savings', 500.00)
),
inserted_budgets AS (
  INSERT INTO budgets (user_id, category_id, month, amount)
  SELECT inserted_categories.user_id, inserted_categories.id, DATE '2026-06-01', budget_seed.amount
  FROM inserted_categories
  JOIN budget_seed ON budget_seed.category_name = inserted_categories.name
  ON CONFLICT (user_id, category_id, month) DO UPDATE
    SET amount = EXCLUDED.amount
  RETURNING id
),
transaction_seed (transaction_date, paid_by, paid_to, ticket_code, currency, total_amount) AS (
  VALUES
    (DATE '2026-06-01', 'Checking', 'Landlord', 'rent-2026-06', '$MX', 1200.00),
    (DATE '2026-06-02', 'Debit card', 'Grocery store', 'groceries-2026-06-02', '$MX', 86.35),
    (DATE '2026-06-03', 'Cash', 'Metro', 'metro-2026-06-03', '$MX', 40.00),
    (DATE '2026-06-04', 'Checking', 'Utility company', 'utilities-2026-06', '$MX', 96.12)
),
inserted_transactions AS (
  INSERT INTO transactions (user_id, transaction_date, paid_by, paid_to, ticket_code, currency, total_amount)
  SELECT inserted_user.id,
         transaction_seed.transaction_date,
         transaction_seed.paid_by,
         transaction_seed.paid_to,
         transaction_seed.ticket_code,
         transaction_seed.currency,
         transaction_seed.total_amount
  FROM inserted_user
  CROSS JOIN transaction_seed
  WHERE NOT EXISTS (
    SELECT 1
    FROM transactions t
    WHERE t.user_id = inserted_user.id
      AND t.ticket_code = transaction_seed.ticket_code
  )
  RETURNING id, user_id, ticket_code
),
all_transactions AS (
  SELECT id, user_id, ticket_code FROM inserted_transactions
  UNION
  SELECT t.id, t.user_id, t.ticket_code
  FROM transactions t
  JOIN inserted_user ON inserted_user.id = t.user_id
  WHERE t.ticket_code IN ('rent-2026-06', 'groceries-2026-06-02', 'metro-2026-06-03', 'utilities-2026-06')
),
item_seed (ticket_code, category_name, item, units, unit_price, total_price) AS (
  VALUES
    ('rent-2026-06', 'Housing', 'Rent payment', 1, 1200.00, 1200.00),
    ('groceries-2026-06-02', 'Food', 'Groceries', 1, 58.37, 58.37),
    ('groceries-2026-06-02', 'Entertainment', 'Streaming services', 1, 27.98, 27.98),
    ('metro-2026-06-03', 'Transportation', 'Metro card recharge', 1, 40.00, 40.00),
    ('utilities-2026-06', 'Utilities', 'Electric bill', 1, 96.12, 96.12)
)
INSERT INTO transaction_items (user_id, transaction_id, category_id, item, units, unit_price, total_price)
SELECT all_transactions.user_id,
       all_transactions.id,
       inserted_categories.id,
       item_seed.item,
       item_seed.units,
       item_seed.unit_price,
       item_seed.total_price
FROM item_seed
JOIN all_transactions ON all_transactions.ticket_code = item_seed.ticket_code
JOIN inserted_categories ON inserted_categories.user_id = all_transactions.user_id
  AND inserted_categories.name = item_seed.category_name
WHERE NOT EXISTS (
  SELECT 1
  FROM transaction_items ti
  WHERE ti.user_id = all_transactions.user_id
    AND ti.transaction_id = all_transactions.id
    AND ti.item = item_seed.item
);


INSERT INTO accounts (user_id, name)
SELECT DISTINCT user_id, paid_by
FROM transactions
WHERE paid_by IS NOT NULL AND btrim(paid_by) <> ''
ON CONFLICT (user_id, name) DO NOTHING;

INSERT INTO accounts (user_id, name)
SELECT DISTINCT user_id, paid_to
FROM transactions
WHERE paid_to IS NOT NULL AND btrim(paid_to) <> ''
ON CONFLICT (user_id, name) DO NOTHING;

UPDATE transactions t
SET paid_by_account_id = a.id
FROM accounts a
WHERE a.user_id = t.user_id
  AND a.name = t.paid_by
  AND t.paid_by_account_id IS NULL;

UPDATE transactions t
SET paid_to_account_id = a.id
FROM accounts a
WHERE a.user_id = t.user_id
  AND a.name = t.paid_to
  AND t.paid_to_account_id IS NULL;
