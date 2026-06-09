\echo 'Temizleme, tipleme ve turetilmis kolonlar hesaplaniyor...'
DROP TABLE IF EXISTS clean_customer_candidates;

CREATE TABLE clean_customer_candidates AS
WITH text_clean AS (
    SELECT
        staging_id,
        NULLIF(initcap(lower(trim(first_name_raw))), '') AS first_name_clean,
        NULLIF(initcap(lower(trim(last_name_raw))), '') AS last_name_clean,
        lower(trim(coalesce(email_raw, ''))) AS email_clean,
        regexp_replace(coalesce(phone_raw, ''), '\D', '', 'g') AS phone_digits,
        initcap(lower(coalesce(nullif(trim(city_raw), ''), 'Bilinmiyor'))) AS city_clean,
        trim(coalesce(country_raw, 'TR')) AS country_clean,
        trim(coalesce(order_date_raw, '')) AS date_raw,
        trim(coalesce(age_raw, '')) AS age_text,
        trim(coalesce(product_id_raw, '')) AS product_text,
        trim(coalesce(quantity_raw, '')) AS quantity_text,
        trim(coalesce(unit_price_raw, '')) AS price_text
    FROM staging_customers
),
typed AS (
    SELECT
        staging_id,
        first_name_clean,
        last_name_clean,
        CASE
            WHEN email_clean ~* '^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$'
            THEN email_clean
        END AS email,
        CASE
            WHEN phone_digits ~ '^90[0-9]{10}$' THEN '+' || phone_digits
            WHEN phone_digits ~ '^0[0-9]{10}$' THEN '+90' || substring(phone_digits FROM 2)
            WHEN phone_digits ~ '^[0-9]{10}$' THEN '+90' || phone_digits
        END AS phone,
        CASE
            WHEN age_text ~ '^\d+$' AND age_text::integer BETWEEN 0 AND 120
            THEN age_text::integer
        END AS age,
        CASE
            WHEN date_raw ~ '^\d{4}-\d{2}-\d{2}$' THEN to_date(date_raw, 'YYYY-MM-DD')
            WHEN date_raw ~ '^\d{2}/\d{2}/\d{4}$' THEN to_date(date_raw, 'DD/MM/YYYY')
            WHEN date_raw ~ '^\d{2}\.\d{2}\.\d{4}$' THEN to_date(date_raw, 'DD.MM.YYYY')
        END AS order_date,
        CASE
            WHEN product_text ~ '^\d+$' THEN product_text::integer
        END AS product_id,
        CASE
            WHEN quantity_text ~ '^\d+$' AND quantity_text::integer > 0
            THEN quantity_text::integer
        END AS quantity,
        CASE
            WHEN price_text ~ '^\d+(\.\d+)?$' AND price_text::numeric >= 0
            THEN price_text::numeric(12,2)
        END AS unit_price,
        lower(city_clean) AS city_alias
    FROM text_clean
),
business_ready AS (
    SELECT
        t.staging_id AS source_staging_id,
        t.first_name_clean,
        t.last_name_clean,
        concat_ws(' ', t.first_name_clean, t.last_name_clean) AS full_name,
        t.email,
        t.phone,
        t.age,
        CASE
            WHEN t.age < 25 THEN '18-24'
            WHEN t.age < 35 THEN '25-34'
            WHEN t.age < 50 THEN '35-49'
            WHEN t.age IS NOT NULL THEN '50+'
        END AS age_group,
        CASE
            WHEN t.quantity * t.unit_price >= 1000 THEN 'Premium'
            WHEN t.quantity * t.unit_price >= 250 THEN 'Standart'
            WHEN t.quantity IS NOT NULL AND t.unit_price IS NOT NULL THEN 'Yeni'
        END AS customer_segment,
        coalesce(l.city_name, 'Bilinmiyor') AS city,
        coalesce(l.country_code, 'TR') AS country_code,
        t.order_date,
        t.product_id,
        t.quantity,
        t.unit_price,
        ROW_NUMBER() OVER (
            PARTITION BY t.email, t.phone
            ORDER BY t.order_date DESC NULLS LAST, t.staging_id DESC
        ) AS rn
    FROM typed t
    LEFT JOIN dim_city_lookup l
      ON lower(t.city_alias) = l.city_alias
)
SELECT *
FROM business_ready;

\echo 'Aday kayit ozeti:'
SELECT
    COUNT(*) AS candidate_count,
    COUNT(*) FILTER (
        WHERE first_name_clean IS NOT NULL
          AND last_name_clean IS NOT NULL
          AND email IS NOT NULL
          AND phone IS NOT NULL
          AND age IS NOT NULL
          AND order_date IS NOT NULL
          AND product_id IS NOT NULL
          AND quantity IS NOT NULL
          AND unit_price IS NOT NULL
    ) AS valid_candidate_count,
    COUNT(*) FILTER (WHERE rn > 1) AS duplicate_candidate_count
FROM clean_customer_candidates;

\echo 'Gecersiz ve duplicate kayitlar rejected_records tablosuna ayriliyor...'
TRUNCATE rejected_records;

INSERT INTO rejected_records (staging_id, reject_reason, raw_record)
SELECT
    s.staging_id,
    CASE
        WHEN c.first_name_clean IS NULL OR c.last_name_clean IS NULL THEN 'Eksik ad veya soyad'
        WHEN c.email IS NULL THEN 'Gecersiz veya eksik e-posta'
        WHEN c.phone IS NULL THEN 'Gecersiz veya eksik telefon'
        WHEN c.age IS NULL THEN 'Gecersiz yas'
        WHEN c.order_date IS NULL THEN 'Gecersiz tarih'
        WHEN c.product_id IS NULL THEN 'Gecersiz urun'
        WHEN c.quantity IS NULL THEN 'Gecersiz miktar'
        WHEN c.unit_price IS NULL THEN 'Gecersiz fiyat'
        WHEN c.rn > 1 THEN 'Duplicate kayit'
        ELSE 'Diger is kurali ihlali'
    END AS reject_reason,
    to_jsonb(s) AS raw_record
FROM staging_customers s
JOIN clean_customer_candidates c
  ON c.source_staging_id = s.staging_id
WHERE c.first_name_clean IS NULL
   OR c.last_name_clean IS NULL
   OR c.email IS NULL
   OR c.phone IS NULL
   OR c.age IS NULL
   OR c.order_date IS NULL
   OR c.product_id IS NULL
   OR c.quantity IS NULL
   OR c.unit_price IS NULL
   OR c.rn > 1;

\echo 'Final tabloya temiz kayitlar yukleniyor...'
TRUNCATE final_customers RESTART IDENTITY;

INSERT INTO final_customers (
    source_staging_id, full_name, email, phone, age, age_group,
    customer_segment, city, country_code, order_date,
    product_id, quantity, unit_price
)
SELECT
    source_staging_id, full_name, email, phone, age, age_group,
    customer_segment, city, country_code, order_date,
    product_id, quantity, unit_price
FROM clean_customer_candidates
WHERE first_name_clean IS NOT NULL
  AND last_name_clean IS NOT NULL
  AND email IS NOT NULL
  AND phone IS NOT NULL
  AND age IS NOT NULL
  AND order_date IS NOT NULL
  AND product_id IS NOT NULL
  AND quantity IS NOT NULL
  AND unit_price IS NOT NULL
  AND rn = 1;

\echo 'Load sonucu:'
SELECT
    (SELECT COUNT(*) FROM staging_customers) AS staging_count,
    (SELECT COUNT(*) FROM final_customers) AS final_count,
    (SELECT COUNT(*) FROM rejected_records) AS rejected_count;
