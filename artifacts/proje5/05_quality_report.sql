\echo 'Quality log yeniden olusturuluyor...'
TRUNCATE quality_log RESTART IDENTITY;

INSERT INTO quality_log (run_name, stage, metric_name, metric_value, metric_unit)
SELECT 'proje5_etl_run', 'before', 'row_count', COUNT(*), 'count'
FROM staging_customers
UNION ALL
SELECT 'proje5_etl_run', 'after', 'row_count', COUNT(*), 'count'
FROM final_customers
UNION ALL
SELECT 'proje5_etl_run', 'after', 'rejected_count', COUNT(*), 'count'
FROM rejected_records
UNION ALL
SELECT 'proje5_etl_run', 'before', 'invalid_email_count',
       COUNT(*) FILTER (
           WHERE lower(trim(coalesce(email_raw, ''))) = ''
              OR lower(trim(coalesce(email_raw, ''))) !~* '^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$'
       ), 'count'
FROM staging_customers
UNION ALL
SELECT 'proje5_etl_run', 'after', 'invalid_email_count',
       COUNT(*) FILTER (
           WHERE email !~* '^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$'
       ), 'count'
FROM final_customers
UNION ALL
SELECT 'proje5_etl_run', 'before', 'duplicate_count',
       COUNT(*), 'count'
FROM clean_customer_candidates
WHERE rn > 1
UNION ALL
SELECT 'proje5_etl_run', 'after', 'duplicate_count',
       GREATEST(COUNT(*) - COUNT(DISTINCT (email, phone)), 0), 'count'
FROM final_customers;

\echo '1) Oncesi / sonrasi karsilastirma'
SELECT metric_name, stage, metric_value, metric_unit
FROM quality_log
ORDER BY metric_name, stage;

\echo '2) Kabul / red oranlari'
SELECT 'staging' AS category, COUNT(*) AS row_count,
       round(COUNT(*) * 100.0 / NULLIF((SELECT COUNT(*) FROM staging_customers), 0), 2) AS ratio_percent
FROM staging_customers
UNION ALL
SELECT 'final', COUNT(*),
       round(COUNT(*) * 100.0 / NULLIF((SELECT COUNT(*) FROM staging_customers), 0), 2)
FROM final_customers
UNION ALL
SELECT 'rejected', COUNT(*),
       round(COUNT(*) * 100.0 / NULLIF((SELECT COUNT(*) FROM staging_customers), 0), 2)
FROM rejected_records;

\echo '3) Red sebepleri'
SELECT reject_reason, COUNT(*) AS rejected_count
FROM rejected_records
GROUP BY reject_reason
ORDER BY rejected_count DESC, reject_reason;

\echo '4) Final tablo doluluk oranlari'
SELECT 'full_name' AS column_name, round(COUNT(full_name) * 100.0 / COUNT(*), 2) AS fill_rate
FROM final_customers
UNION ALL
SELECT 'email', round(COUNT(email) * 100.0 / COUNT(*), 2)
FROM final_customers
UNION ALL
SELECT 'phone', round(COUNT(phone) * 100.0 / COUNT(*), 2)
FROM final_customers
UNION ALL
SELECT 'age', round(COUNT(age) * 100.0 / COUNT(*), 2)
FROM final_customers
UNION ALL
SELECT 'city', round(COUNT(city) * 100.0 / COUNT(*), 2)
FROM final_customers
UNION ALL
SELECT 'order_date', round(COUNT(order_date) * 100.0 / COUNT(*), 2)
FROM final_customers
ORDER BY column_name;

\echo '5) Temizlenen veri orani'
SELECT
    COUNT(*) AS final_clean_rows,
    round(COUNT(*) * 100.0 / NULLIF((SELECT COUNT(*) FROM staging_customers), 0), 2) AS clean_data_percent
FROM final_customers;
