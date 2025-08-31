## Prepare: Setup Containers

To set up the required containers for Debezium CDC from Postgres to ClickHouse, run the following commands:

```sh
docker compose build
docker compose up -d
docker compose ps
```

## Install dbmate

This project uses [dbmate](https://github.com/amacneil/dbmate) for database schema management and migrations.
Please [install](https://github.com/amacneil/dbmate?tab=readme-ov-file#installation) dbmate by following instructions from the official repository.

## PostgreSQL DB Preparation

Run the following commands to check migration status and apply migrations to the PostgreSQL database:

```sh
DATABASE_URL="postgres://postgres:123@127.0.0.1:5432/test?sslmode=disable" dbmate -d ./postgres/migrations status
DATABASE_URL="postgres://postgres:123@127.0.0.1:5432/test?sslmode=disable" dbmate -d ./postgres/migrations up
```
After running migrations, you can check the status and contents of the `orders` table:

```sh
docker compose exec -it postgres psql -Upostgres test
```
```sh
SELECT * FROM orders;

\q
```
## Start Debezium Connector

To start the Debezium connector and begin capturing changes from PostgreSQL, use the following commands:

```sh
curl -i -X PUT -H "Content-Type: application/json" http://localhost:8083/connectors/dbz/config -d@debezium.json
```
This command creates or updates the Debezium connector using the configuration in `debezium.json`.

You can check the connector status with:

```sh
curl -i http://localhost:8083/connectors/dbz/status
```

To restart the connector task (useful if you change the configuration):

```sh
curl -X POST http://localhost:8083/connectors/dbz/tasks/0/restart # skip this command for now
```

To remove the connector:

```sh
curl -i -X DELETE http://localhost:8083/connectors/dbz # skip this command for now
```
You can monitor the Debezium connector logs for troubleshooting or to verify CDC events:

```sh
docker compose logs kconnect
```

## Verify CDC Events in Kafka

After starting the Debezium connector, you can verify that change events are being captured by checking the Kafka UI for messages in the topic `dbz.public.orders`:

- Open [http://127.0.0.1:8080](http://127.0.0.1:8080/ui/clusters/test/all-topics) in your browser.
- Look for the topic `dbz.public.orders` and check the number of messages.
- Start [Live Mode](http://127.0.0.1:8080/ui/clusters/test/all-topics/dbz.public.orders/messages?filterQueryType=STRING_CONTAINS&attempt=4&limit=100&page=0&seekDirection=TAILING&keySerde=String&valueSerde=String&seekType=LATEST)

## Insert and Update Records in PostgreSQL

To generate CDC events, insert and update records in the `orders` table:

```sh
docker compose exec -it postgres psql -Upostgres test
```
```sh
INSERT INTO orders (seller_id, buyer_id, created_at, updated_at, price, comment)
VALUES (
	(FLOOR(random() * 100 + 1))::int, -- seller_id between 1 and 100
	(FLOOR(random() * 1000 + 1))::int, -- buyer_id between 1 and 1000
	NOW(),
	NOW(),
	ROUND((random() * 500)::numeric, 2), -- price between 0 and 500 with 2 decimals
	(ARRAY['First order','Test purchase','Sample comment','High value order','Repeat buyer'])[floor(random() * 5 + 1)]
);

UPDATE orders SET comment = 'Updated comment' WHERE id = 7;

\q
```
These operations will produce new messages in the Kafka topic, which you can observe in the Kafka UI.

## ClickHouse DB Preparation

Prepare the ClickHouse database and apply migrations using dbmate:

```sh
DATABASE_URL="clickhouse://default:123@127.0.0.1:9000/default" dbmate -d ./clickhouse/migrations status
DATABASE_URL="clickhouse://default:123@127.0.0.1:9000/default" dbmate -d ./clickhouse/migrations up
```

To connect to ClickHouse and check the contents of the `orders` table:

```sh
docker compose exec -it clickhouse clickhouse-client -f Pretty -q "SELECT * FROM default.orders;" # empty output
docker compose exec -it clickhouse clickhouse-client -f Pretty -q "SHOW CREATE TABLE default.orders;"
```

## Start ClickHouse Sink Connector

To stream data from Kafka to ClickHouse, configure and manage the ClickHouse sink connector using the following commands:

```sh
curl -i -X PUT -H "Content-Type: application/json" http://localhost:8083/connectors/clickhouse-sink/config -d@clickhouse-sink.json
```
This command creates or updates the ClickHouse sink connector using the configuration in `clickhouse-sink.json`.

Check the status of the connector:

```sh
curl -i http://localhost:8083/connectors/clickhouse-sink/status
```

Restart the connector task (useful after configuration changes):

```sh
curl -X POST http://localhost:8083/connectors/clickhouse-sink/tasks/0/restart # skip this command for now
```

Remove the connector:

```sh
curl -i -X DELETE http://localhost:8083/connectors/clickhouse-sink # skip this command for now
```

Check new records are present in Clickhouse:
```sh
docker compose exec -it clickhouse clickhouse-client -f Pretty -q "SELECT * FROM default.orders;"
```

## Insert and Update the Same Record Multiple Times

To test CDC and deduplication in ClickHouse, insert a record and update the same record twice in PostgreSQL:

```sh
docker compose exec -it postgres psql -Upostgres test
```
```sh
INSERT INTO orders (seller_id, buyer_id, created_at, updated_at, price, comment)
VALUES (
	(FLOOR(random() * 100 + 1))::int, -- seller_id between 1 and 100
	(FLOOR(random() * 1000 + 1))::int, -- buyer_id between 1 and 1000
	NOW(),
	NOW(),
	ROUND((random() * 500)::numeric, 2), -- price between 0 and 500 with 2 decimals
	(ARRAY['First order','Test purchase','Sample comment','High value order','Repeat buyer'])[floor(random() * 5 + 1)]
);

UPDATE orders SET comment = 'Updated comment 1' WHERE id = 7;
UPDATE orders SET comment = 'Updated comment 2' WHERE id = 7;

\q
```

## Check Results in ClickHouse

To view the records in ClickHouse, run the following queries:

Without FINAL (shows all versions) and with:
```sh
docker compose exec -it clickhouse clickhouse-client -f Pretty -q "SELECT * FROM orders WHERE id = '7' ORDER BY updated_at DESC;"
docker compose exec -it clickhouse clickhouse-client -f Pretty -q "SELECT * FROM orders FINAL WHERE id = '7' ORDER BY updated_at DESC;"

```

## Run Snapshot via Kafka UI

To trigger a snapshot of the `public.orders` table, produce a message to the `dbz_signals` topic in Kafka UI:

1. Open [http://127.0.0.1:8080/ui/clusters/test/all-topics/dbz_signals](http://127.0.0.1:8080/ui/clusters/test/all-topics/dbz_signals).
2. Select the topic `dbz_signals` and choose "Produce message".
3. Use the following key and value:

**Key:**
```
dbz
```

**Value:**
```json
{
	"type": "execute-snapshot",
	"data": {
		"data-collections": [
			"public.orders"
		],
		"type": "blocking",
		"additional-conditions": [
			{
				"data-collection": "public.orders",
				"filter": "SELECT * FROM public.orders WHERE id >= 2 and id < 6 ORDER BY id"
			}
		]
	}
}
```

Check connector logs for detailed info:
```sh
docker compose logs kconnect -f
```


## Avro Serialization

To enable Avro serialization for Debezium messages, add the following properties to your connector configuration (see `debezium-avro.json`):

```json
	"key.converter": "io.confluent.connect.avro.AvroConverter",
	"key.converter.schema.registry.url": "http://schema-registry:8081",
	"value.converter": "io.confluent.connect.avro.AvroConverter",
	"value.converter.schema.registry.url": "http://schema-registry:8081",
```

This configuration enables Avro serialization and registers schemas in the Schema Registry. You can compare message sizes in Kafka UI between JSON and Avro formats:


### Start Avro Connector

To start a new Debezium connector with Avro serialization, use:

### Start Debezium and ClickHouse Sink Connectors with Avro

To start both the Debezium connector and the ClickHouse sink connector with Avro serialization, use the following commands:

```sh
# Start Debezium connector with Avro
curl -i -X PUT -H "Content-Type: application/json" http://localhost:8083/connectors/dbz/config -d@debezium-avro.json

# Start ClickHouse sink connector with Avro
curl -i -X PUT -H "Content-Type: application/json" http://localhost:8083/connectors/clickhouse-sink/config -d@clickhouse-sink-avro.json
```
These commands create or update the connectors using their respective Avro configuration files.

Generate data in postgres:

To generate data in PostgreSQL for Avro testing, run:

```sh
docker compose exec -it postgres psql -Upostgres test
```
```sh
INSERT INTO orders (seller_id, buyer_id, created_at, updated_at, price, comment)
VALUES (
	(FLOOR(random() * 100 + 1))::int, -- seller_id between 1 and 100
	(FLOOR(random() * 1000 + 1))::int, -- buyer_id between 1 and 1000
	NOW(),
	NOW(),
	ROUND((random() * 500)::numeric, 2), -- price between 0 and 500 with 2 decimals
	(ARRAY['First order','Test purchase','Sample comment','High value order','Repeat buyer'])[floor(random() * 5 + 1)]
);

\q
```

To check messages in Kafka UI:

- **As strings:**
	[View messages as strings](http://127.0.0.1:8080/ui/clusters/test/all-topics/dbz.public.orders/messages?filterQueryType=STRING_CONTAINS&attempt=3&limit=100&page=0&seekDirection=BACKWARD&keySerde=String&valueSerde=String&seekType=LATEST)
- **Using schema registry:**
	[View messages with schema registry](http://127.0.0.1:8080/ui/clusters/test/all-topics/dbz.public.orders/messages?filterQueryType=STRING_CONTAINS&attempt=4&limit=100&page=0&seekDirection=BACKWARD&keySerde=SchemaRegistry&valueSerde=SchemaRegistry&seekType=LATEST)

## Destroy All Containers

To stop and remove all containers, networks, and volumes created by Docker Compose:

```sh
docker compose down
```
