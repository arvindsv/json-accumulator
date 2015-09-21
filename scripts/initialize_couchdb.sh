#!/bin/bash

# Assumption: couchdb can be started using entrypoint.sh (meaning, the base container is a couchdb container).

set -xe

COUCHDB_PORT=${COUCHDB_PORT:-5984}
COUCHDB_BASE_URL=${COUCHDB_BASE_URL:-http://$COUCHDB_USER:$COUCHDB_PASS@localhost:${COUCHDB_PORT}}

# Start couch in the background
mkdir -p /var/log/couchdb
chown couchdb:couchdb /var/log/couchdb
bash -x /entrypoint.sh couchdb -b -o /var/log/couchdb/couchdb.stdout -e /var/log/couchdb/couchdb.stderr

while ! curl -s -o /dev/null "${COUCHDB_BASE_URL}"; do
    echo "Waiting for couchdb to start ..."
    sleep 1
done

# Initialize "schemas"
(cd ./schemas; for each_schema in *; do
    echo "Initializing schema: $each_schema"
    curl -X PUT "${COUCHDB_BASE_URL}/${each_schema}"
done)
