ARG DEBEZIUM_VERSION=3.2.1
ARG CONFLUENT_VERSION=8.0.0
ARG CLICKHOUSE_KAFKA_CONNECT_VERSION=1.3.1

FROM confluentinc/cp-kafka-connect:${CONFLUENT_VERSION} as cp
ARG CONFLUENT_VERSION
ARG CLICKHOUSE_KAFKA_CONNECT_VERSION
RUN confluent-hub install --no-prompt confluentinc/kafka-connect-avro-converter:${CONFLUENT_VERSION}
RUN confluent-hub install --no-prompt clickhouse/clickhouse-kafka-connect:v${CLICKHOUSE_KAFKA_CONNECT_VERSION}

FROM quay.io/debezium/connect:${DEBEZIUM_VERSION} as dbz
COPY --from=cp --chown=kafka:kafka /usr/share/confluent-hub-components/confluentinc-kafka-connect-avro-converter/lib /kafka/connect/avro
COPY --from=cp --chown=kafka:kafka /usr/share/confluent-hub-components/clickhouse-clickhouse-kafka-connect /kafka/connect/clickhouse
