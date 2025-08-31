-- migrate:up
CREATE PUBLICATION dbz_pub
    FOR TABLE orders
    WITH (publish = 'insert, update');

-- migrate:down
DROP PUBLICATION IF EXISTS dbz_pub;
