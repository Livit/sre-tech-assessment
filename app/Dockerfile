# This Dockerifle is obviusly overkill for this app

FROM alpine:3.13.6 AS base
RUN apk add --no-cache --update nodejs npm tini
WORKDIR /root
COPY package.json .

ENTRYPOINT ["/sbin/tini", "--"]

FROM base AS dependencies
RUN npm set progress=false && npm config set depth 0
RUN npm install
RUN cp -R node_modules prod_node_modules

RUN npm install


FROM dependencies AS test
COPY . .
RUN  npm run lint && npm run setup && npm run test


FROM base AS release
COPY --from=dependencies /root/prod_node_modules ./node_modules

COPY . .

EXPOSE 80

CMD npm run start
#CMD npm run start