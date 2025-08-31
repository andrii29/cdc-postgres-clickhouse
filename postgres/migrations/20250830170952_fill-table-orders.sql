-- migrate:up
INSERT INTO orders (seller_id, buyer_id, created_at, updated_at, price, comment)
VALUES
    (1, 101, NOW(), NOW(), 49.99, 'First order'),
    (2, 102, NOW(), NOW(), 120.50, 'Bulk purchase'),
    (3, 103, NOW(), NOW(), 15.00, 'Test order'),
    (1, 104, NOW(), NOW(), 75.25, 'Repeat buyer'),
    (4, 105, NOW(), NOW(), 200.00, 'High value order'),
    (2, 106, NOW(), NOW(), 33.33, 'Discount applied'),
    (5, 107, NOW(), NOW(), 99.99, 'Special request'),
    (3, 108, NOW(), NOW(), 10.00, 'Small item'),
    (4, 109, NOW(), NOW(), 150.75, 'Expedited shipping'),
    (1, 110, NOW(), NOW(), 250.00, 'Large order');


-- migrate:down
DELETE FROM orders WHERE id IN <= 10;
