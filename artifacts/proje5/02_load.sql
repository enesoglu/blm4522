\echo 'CSV staging_customers tablosuna yukleniyor...'
COPY staging_customers (
    first_name_raw, last_name_raw, email_raw, phone_raw, age_raw,
    city_raw, country_raw, order_date_raw, product_id_raw,
    quantity_raw, unit_price_raw
)
FROM 'C:/Users/yildi/projects_db/blm4522/artifacts/proje5/dirty_customers.csv'
WITH (
    FORMAT csv,
    HEADER true,
    NULL '',
    ENCODING 'UTF8'
);

\echo 'Yukleme sonrasi satir sayisi:'
SELECT COUNT(*) AS staging_row_count
FROM staging_customers;
