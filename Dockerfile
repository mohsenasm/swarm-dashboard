FROM node:8-alpine AS base

RUN apk add --update tini curl \
  && rm -r /var/cache
ENTRYPOINT ["/sbin/tini", "--"]
WORKDIR /home/node/app

FROM base AS dependencies

ENV NODE_ENV production

COPY package.json yarn.lock ./
RUN yarn install --production

# elm doesn't work under alpine 6 or 8
FROM node:6-slim AS elm-build
WORKDIR /home/node/app

RUN npm install -g elm --silent

COPY elm-package.json ./
RUN elm package install -y

COPY . .

RUN elm make Main.elm --output=client/index.js

FROM base AS release

WORKDIR /home/node/app

COPY --from=dependencies /home/node/app/node_modules node_modules
COPY --from=elm-build /home/node/app/client/ client
COPY server server

HEALTHCHECK --interval=5s --timeout=3s \
  CMD curl --fail http://localhost:$PORT/_health || exit 1

# Run under Tini
CMD ["node", "server/index.js"]
