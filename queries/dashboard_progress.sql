SELECT
  b.id AS budget_id,
  c.id AS category_id,
  c.name AS category,
  b.month,
  b.amount AS budget_amount,
  COALESCE(SUM(ti.total_price), 0) AS spent,
  b.amount - COALESCE(SUM(ti.total_price), 0) AS remaining,
  CASE
    WHEN b.amount = 0 THEN 0
    ELSE COALESCE(SUM(ti.total_price), 0) / b.amount * 100
  END AS progress
FROM budgets b
JOIN categories c ON c.id = b.category_id
LEFT JOIN transactions t
  ON t.user_id = b.user_id
  AND date_trunc('month', t.transaction_date)::date = b.month
LEFT JOIN transaction_items ti
  ON ti.user_id = t.user_id
  AND ti.transaction_id = t.id
  AND ti.category_id = b.category_id
WHERE b.user_id = $1
  AND b.month = $2
GROUP BY b.id, c.id, c.name, b.month, b.amount
ORDER BY c.sort_order, c.name;
