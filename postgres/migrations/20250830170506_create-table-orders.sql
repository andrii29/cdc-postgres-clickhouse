-- migrate:up
CREATE TABLE orders (
    id SERIAL PRIMARY KEY,
    seller_id INTEGER NOT NULL,
    buyer_id INTEGER NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    price DOUBLE PRECISION NOT NULL,
    deleted BOOLEAN NOT NULL DEFAULT FALSE,
    comment TEXT
);


-- migrate:down
DROP TABLE orders;
