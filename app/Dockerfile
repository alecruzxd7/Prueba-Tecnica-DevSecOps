# syntax=docker/dockerfile:1
#
# build-web: compila el frontend React con Vite (necesita devDependencies).
# deps:      instala unicamente dependencias de producción (express).
# runtime:   distroless, usuario no-root.
#
# Las imágenes base están fijadas por versión Y digest para builds reproducibles.

ARG NODE_IMAGE=node:24.15.0-bookworm-slim@sha256:4e6b70dd6cbfc88c8157ba19aa3d9f9cce6ba4703576d55459e45efcbc9c5f5d
ARG RUNTIME_IMAGE=gcr.io/distroless/nodejs24-debian12:nonroot@sha256:14d42e2511532589a7c7e01a753667a74fcc96266e137e8125006b87b0c32d0a

# 1- Build del frontend
FROM ${NODE_IMAGE} AS build-web
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --no-audit --no-fund
COPY vite.config.js ./
COPY web ./web
RUN npm run build

# 2- Dependencias de produccion
FROM ${NODE_IMAGE} AS deps
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev --no-audit --no-fund

# 3- Runtime
FROM ${RUNTIME_IMAGE} AS runtime
WORKDIR /app

ARG APP_VERSION=dev
ENV NODE_ENV=production \
    PORT=8080 \
    APP_VERSION=${APP_VERSION}

COPY --from=deps --chown=nonroot:nonroot /app/node_modules ./node_modules
COPY --chown=nonroot:nonroot package.json ./
COPY --chown=nonroot:nonroot server ./server
COPY --from=build-web --chown=nonroot:nonroot /app/dist ./dist

# UID 65532 = nonroot en distroless. Se declara explícito aunque la base ya lo use.
USER 65532:65532
EXPOSE 8080

# El ENTRYPOINT de distroless/nodejs ya es "node"; solo pasamos el script.
CMD ["server/index.js"]
