# Multi-service build: pass SERVICE as a build arg (intake-api | enrich-worker | connectors | score-runner)
FROM node:22-slim AS build
ARG SERVICE=intake-api
WORKDIR /app

COPY package.json package-lock.json* ./
COPY shared/schema/package.json ./shared/schema/
COPY services/intake-api/package.json ./services/intake-api/
COPY services/enrich-worker/package.json ./services/enrich-worker/
COPY services/connectors/package.json ./services/connectors/
COPY services/score-runner/package.json ./services/score-runner/
RUN npm install

COPY . .
RUN npm run build -w @pp/schema && npm run build -w @pp/${SERVICE}

FROM node:22-slim AS runtime
ARG SERVICE
ENV NODE_ENV=production
WORKDIR /app

COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/package.json ./package.json
COPY --from=build /app/shared ./shared
COPY --from=build /app/services/${SERVICE} ./services/${SERVICE}
# Fixtures + specs are read at runtime by connectors/score-runner.
COPY --from=build /app/fixtures ./fixtures
COPY --from=build /app/evidence_specs ./evidence_specs

ENV SERVICE=${SERVICE}
WORKDIR /app/services/${SERVICE}
CMD ["node", "dist/index.js"]
