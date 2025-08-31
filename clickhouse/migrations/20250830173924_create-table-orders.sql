-- migrate:up
CREATE TABLE default.orders
(
    id UInt32,
    seller_id UInt32,
    buyer_id UInt32,
    created_at DateTime64(3, 'UTC') DEFAULT now(),
    updated_at DateTime64(3, 'UTC') DEFAULT now(),
    price Float64,
    comment String
)
ENGINE = ReplacingMergeTree(updated_at)
PARTITION BY toDate(created_at)
ORDER BY (created_at, seller_id, buyer_id, id);


-- migrate:down
DROP TABLE IF EXISTS default.orders;
