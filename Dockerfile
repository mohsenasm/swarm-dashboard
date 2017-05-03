FROM node:6-slim

RUN npm install -g elm --silent > /dev/null

WORKDIR /home/node/app
ENV NODE_ENV production

COPY package.json yarn.lock elm-package.json ./
RUN yarn install --production
run elm package install -y

COPY . ./

RUN elm make Main.elm --output=client/index.js

ARG port
EXPOSE $port
ENV PORT $port
HEALTHCHECK --interval=5s --timeout=3s \
  CMD curl --fail http://localhost:$PORT/_health || exit 1

# Run under Tini
CMD ["node", "server/index.js"]
