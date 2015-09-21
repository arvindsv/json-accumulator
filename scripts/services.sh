#!/bin/bash

# Expectation: This is run inside a Docker container, where ./run.rb exists, and is a Sinatra
# server. Also, ./initialize_couchdb.sh exists.

set -xe

cd $(dirname $0)
bash ./initialize_couchdb.sh
ruby2.0 ./run.rb
