DROP TABLE IF EXISTS quality_log CASCADE;
DROP TABLE IF EXISTS rejected_records CASCADE;
DROP TABLE IF EXISTS final_customers CASCADE;
DROP TABLE IF EXISTS clean_customer_candidates CASCADE;
DROP TABLE IF EXISTS dim_city_lookup CASCADE;
DROP TABLE IF EXISTS staging_customers CASCADE;

CREATE TABLE staging_customers (
    staging_id       bigserial PRIMARY KEY,
    source_file      text DEFAULT 'dirty_customers.csv',
    first_name_raw   text,
    last_name_raw    text,
    email_raw        text,
    phone_raw        text,
    age_raw          text,
    city_raw         text,
    country_raw      text,
    order_date_raw   text,
    product_id_raw   text,
    quantity_raw     text,
    unit_price_raw   text,
    loaded_at        timestamptz DEFAULT now()
);

CREATE TABLE dim_city_lookup (
    city_alias   text PRIMARY KEY,
    city_name    text NOT NULL,
    country_code char(2) NOT NULL
);

INSERT INTO dim_city_lookup (city_alias, city_name, country_code) VALUES
('ankara', 'Ankara', 'TR'),
('istanbul', 'Istanbul', 'TR'),
('izmir', 'Izmir', 'TR'),
('bursa', 'Bursa', 'TR'),
('konya', 'Konya', 'TR'),
('antalya', 'Antalya', 'TR'),
('eskisehir', 'Eskisehir', 'TR'),
('adana', 'Adana', 'TR'),
('bilinmiyor', 'Bilinmiyor', 'TR');

CREATE TABLE final_customers (
    customer_id       bigserial PRIMARY KEY,
    source_staging_id bigint NOT NULL UNIQUE,
    full_name         text NOT NULL,
    email             text NOT NULL,
    phone             text NOT NULL,
    age               integer NOT NULL CHECK (age BETWEEN 0 AND 120),
    age_group         text NOT NULL,
    customer_segment  text NOT NULL,
    city              text NOT NULL,
    country_code      char(2) NOT NULL,
    order_date        date NOT NULL,
    product_id        integer NOT NULL,
    quantity          integer NOT NULL CHECK (quantity > 0),
    unit_price        numeric(12,2) NOT NULL CHECK (unit_price >= 0),
    total_amount      numeric(12,2)
        GENERATED ALWAYS AS (quantity * unit_price) STORED,
    loaded_at         timestamptz DEFAULT now(),
    UNIQUE (email, phone),
    CHECK (email ~* '^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$'),
    CHECK (phone ~ '^\+90[0-9]{10}$')
);

CREATE TABLE rejected_records (
    rejected_id   bigserial PRIMARY KEY,
    staging_id    bigint NOT NULL,
    reject_reason text NOT NULL,
    raw_record    jsonb NOT NULL,
    rejected_at   timestamptz DEFAULT now()
);

CREATE TABLE quality_log (
    log_id       bigserial PRIMARY KEY,
    run_name     text NOT NULL,
    stage        text NOT NULL,
    metric_name  text NOT NULL,
    metric_value numeric(18,4) NOT NULL,
    metric_unit  text DEFAULT 'count',
    details      jsonb,
    measured_at  timestamptz DEFAULT now()
);
