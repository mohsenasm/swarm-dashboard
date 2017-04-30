#!/usr/bin/env sh

docker-compose -f compose.yml build
docker-compose -f compose.yml push

docker stack deploy -c compose.yml services
