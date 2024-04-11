FROM node:20-alpine AS base
RUN apk add --no-cache --update tini lego curl
ENTRYPOINT ["/sbin/tini", "--"]
WORKDIR /home/node/app

FROM base AS dependencies
ENV NODE_ENV production
COPY package.json yarn.lock ./
RUN yarn install --production

FROM --platform=linux/amd64 node:10.16.0-buster-slim AS elm-build
RUN npm install --unsafe-perm -g elm@latest-0.18.0 --silent
RUN apt-get -qq update && apt-get install -y netbase && rm -rf /var/lib/apt/lists/*
WORKDIR /home/node/app/elm-client
COPY ./elm-client/elm-package.json .
RUN elm package install -y
COPY ./elm-client/ /home/node/app/elm-client/
RUN elm make Main.elm --output=client/index.js

FROM base AS release
ENV LEGO_PATH=/lego-files

COPY --from=dependencies /home/node/app/node_modules node_modules
COPY --from=elm-build /home/node/app/elm-client/client/ client
COPY server server
COPY server.sh server.sh
COPY healthcheck.sh healthcheck.sh
COPY crontab /var/spool/cron/crontabs/root

ENV PORT=8080
# HEALTHCHECK --interval=60s --timeout=30s \
#   CMD sh healthcheck.sh

# Run under Tini
CMD ["sh", "server.sh"]
