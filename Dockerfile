FROM node:24-alpine AS base
RUN apk add --no-cache --update tini 'lego=~4' curl
ENTRYPOINT ["/sbin/tini", "--"]
WORKDIR /home/node/app

FROM base AS dependencies
ENV NODE_ENV production
COPY package.json yarn.lock ./
RUN yarn install --production

FROM --platform=linux/amd64 node:24-alpine AS elm-build
RUN npm install -g elm@latest-0.19.1 uglify-js --silent
WORKDIR /home/node/app/elm-client
COPY ./elm-client/elm.json ./elm.json
COPY ./elm-client/src ./src
COPY ./elm-client/client ./client
# RUN elm make src/Main.elm --output=client/index.js
RUN elm make src/Main.elm --optimize --output=client/index.js && uglifyjs client/index.js --compress "pure_funcs=[F2,F3,F4,F5,F6,F7,F8,F9,A2,A3,A4,A5,A6,A7,A8,A9],pure_getters,keep_fargs=false,unsafe_comps,unsafe" | uglifyjs --mangle --output client/index.min.js
# FROM --platform=linux/amd64 mohsenasm/swarm-dashboard:v2.6 AS elm-copy

FROM base AS release
ENV LEGO_PATH=/lego-files
COPY --from=dependencies /home/node/app/node_modules node_modules
COPY --from=elm-build /home/node/app/elm-client/client/ client
# COPY --from=elm-copy /home/node/app/client client
COPY package.json package.json
COPY server server
COPY server.sh server.sh
COPY healthcheck.sh healthcheck.sh
COPY crontab /var/spool/cron/crontabs/root

ENV PORT=8080
# HEALTHCHECK --interval=60s --timeout=30s \
#   CMD sh healthcheck.sh

# Run under Tini
CMD ["sh", "server.sh"]
