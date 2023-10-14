FROM node:10-alpine AS base
RUN apk add --update tini curl \
  && rm -r /var/cache
ENTRYPOINT ["/sbin/tini", "--"]
WORKDIR /home/node/app

FROM base AS dependencies
ENV NODE_ENV production
COPY package.json yarn.lock ./
RUN yarn install --production

# elm doesn't work under alpine 6 or 8
FROM node:10.16.0-buster-slim AS elm-build
WORKDIR /home/node/app
RUN npm install --unsafe-perm -g elm@latest-0.18.0 --silent
RUN apt-get update; apt-get install -y netbase
COPY elm-package.json ./
RUN elm package install -y
COPY . .
RUN elm make Main.elm --output=client/index.js

FROM base AS release
WORKDIR /home/node/app
RUN wget -O lego_v4.14.2_linux_amd64.tar.gz https://github.com/go-acme/lego/releases/download/v4.14.2/lego_v4.14.2_linux_amd64.tar.gz \
 && tar -xzf lego_v4.14.2_linux_amd64.tar.gz \
 && mv ./lego /usr/local/bin/lego \
 && rm lego_v4.14.2_linux_amd64.tar.gz
ENV LEGO_PATH=/lego-files

COPY --from=dependencies /home/node/app/node_modules node_modules
COPY --from=elm-build /home/node/app/client/ client
COPY server server
COPY server.sh server.sh
COPY crontab /var/spool/cron/crontabs/root

HEALTHCHECK --interval=5s --timeout=3s \
  CMD curl --fail http://localhost:$PORT/_health || exit 1
# Run under Tini
CMD ["sh", "server.sh"]
