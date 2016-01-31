#!/bin/bash

docker rm -vf tweet-repo
docker rmi tweet-repo
docker build -t tweet-repo .

REPO=$(docker run -e RACK_ENV=production -e COUCHDB_USER=admin -e COUCHDB_PASS=password -d -p 4567:4567 -p 59840:5984 --name tweet-repo -v `pwd`/couch:/usr/local/var/lib/couchdb tweet-repo) && docker logs -f "$REPO"
