\echo '1) NULL / bos string analizi'
SELECT 'first_name' AS column_name,
       COUNT(*) FILTER (WHERE NULLIF(trim(first_name_raw), '') IS NULL) AS null_count
FROM staging_customers
UNION ALL
SELECT 'last_name',
       COUNT(*) FILTER (WHERE NULLIF(trim(last_name_raw), '') IS NULL)
FROM staging_customers
UNION ALL
SELECT 'email',
       COUNT(*) FILTER (WHERE NULLIF(trim(email_raw), '') IS NULL)
FROM staging_customers
UNION ALL
SELECT 'phone',
       COUNT(*) FILTER (WHERE NULLIF(trim(phone_raw), '') IS NULL)
FROM staging_customers
UNION ALL
SELECT 'city',
       COUNT(*) FILTER (WHERE NULLIF(trim(city_raw), '') IS NULL)
FROM staging_customers
UNION ALL
SELECT 'order_date',
       COUNT(*) FILTER (WHERE NULLIF(trim(order_date_raw), '') IS NULL)
FROM staging_customers
ORDER BY column_name;

\echo '2) Duplicate analizi - e-posta ve telefon'
WITH normalized AS (
    SELECT
        lower(trim(email_raw)) AS email_norm,
        regexp_replace(coalesce(phone_raw, ''), '\D', '', 'g') AS phone_digits
    FROM staging_customers
)
SELECT email_norm, phone_digits, COUNT(*) AS duplicate_count
FROM normalized
WHERE email_norm IS NOT NULL
  AND email_norm <> ''
  AND phone_digits <> ''
GROUP BY email_norm, phone_digits
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC, email_norm
LIMIT 10;

\echo '3) Format hatalari'
WITH p AS (
    SELECT
        lower(trim(coalesce(email_raw, ''))) AS email_norm,
        regexp_replace(coalesce(phone_raw, ''), '\D', '', 'g') AS phone_digits,
        trim(coalesce(order_date_raw, '')) AS date_raw
    FROM staging_customers
)
SELECT
    COUNT(*) FILTER (
        WHERE email_norm = ''
           OR email_norm !~* '^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$'
    ) AS invalid_email_count,
    COUNT(*) FILTER (
        WHERE phone_digits !~ '^(90)?0?[0-9]{10}$'
    ) AS invalid_phone_count,
    COUNT(*) FILTER (
        WHERE date_raw !~ '^\d{4}-\d{2}-\d{2}$'
          AND date_raw !~ '^\d{2}/\d{2}/\d{4}$'
          AND date_raw !~ '^\d{2}\.\d{2}\.\d{4}$'
    ) AS inconsistent_date_count
FROM p;

\echo '4) Aykiri deger analizi'
SELECT
    SUM(CASE
        WHEN age_raw !~ '^-?\d+$' THEN 1
        WHEN age_raw::integer < 0 OR age_raw::integer > 120 THEN 1
        ELSE 0
    END) AS invalid_age_count,
    SUM(CASE
        WHEN unit_price_raw !~ '^-?\d+(\.\d+)?$' THEN 1
        WHEN unit_price_raw::numeric < 0 THEN 1
        ELSE 0
    END) AS invalid_price_count,
    SUM(CASE
        WHEN quantity_raw !~ '^\d+$' THEN 1
        WHEN quantity_raw::integer <= 0 THEN 1
        ELSE 0
    END) AS invalid_quantity_count
FROM staging_customers;
