-- migrate:up
CREATE USER debezium WITH PASSWORD 'dbz' REPLICATION;
-- GRANT rds_replication TO debezium;
GRANT CONNECT ON DATABASE test TO debezium;
GRANT USAGE ON SCHEMA public TO debezium;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO debezium;

-- migrate:down
DROP USER IF EXISTS debezium;
