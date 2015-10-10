# Build using: docker build -t tweet-repo .
FROM twdevops/couchdb:1.6

RUN apt-get update && apt-get install -y ruby2.0 ruby-sinatra

COPY scripts/ /scripts/
EXPOSE 4567

ENTRYPOINT ["bash", "/scripts/services.sh"]