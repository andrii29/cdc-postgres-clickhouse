
--
-- Database schema
--

CREATE DATABASE IF NOT EXISTS default;

CREATE TABLE default.orders
(
    `id` UInt32,
    `seller_id` UInt32,
    `buyer_id` UInt32,
    `created_at` DateTime64(3, 'UTC') DEFAULT now(),
    `updated_at` DateTime64(3, 'UTC') DEFAULT now(),
    `price` Float64,
    `comment` String
)
ENGINE = ReplacingMergeTree(updated_at)
PARTITION BY toDate(created_at)
ORDER BY (created_at, seller_id, buyer_id, id)
SETTINGS index_granularity = 8192;

CREATE TABLE default.schema_migrations
(
    `version` String,
    `ts` DateTime DEFAULT now(),
    `applied` UInt8 DEFAULT 1
)
ENGINE = ReplacingMergeTree(ts)
PRIMARY KEY version
ORDER BY version
SETTINGS index_granularity = 8192;


--
-- Dbmate schema migrations
--

INSERT INTO schema_migrations (version) VALUES
    ('20250830173924');
