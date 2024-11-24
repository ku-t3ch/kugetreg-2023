##### DEPENDENCIES

FROM --platform=linux/amd64 node:20-alpine AS deps
RUN apk add --no-cache libc6-compat openssl build-base python3
RUN apk add --no-cache \
    udev \
    ttf-freefont \
    chromium
WORKDIR /app

# Install dependencies based on the preferred package manager

COPY package.json yarn.lock* package-lock.json* pnpm-lock.yaml\* ./

RUN yarn global add pnpm && pnpm i

##### BUILDER

FROM --platform=linux/amd64 node:20-alpine AS builder
ARG DATABASE_URL
ARG NEXT_PUBLIC_CLIENTVAR
ARG NEXT_PUBLIC_BUILD_MESSAGE
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .

# ENV NEXT_TELEMETRY_DISABLED 1

RUN yarn global add pnpm && SKIP_ENV_VALIDATION=1 pnpm run build

##### RUNNER

# FROM --platform=linux/amd64 gcr.io/distroless/nodejs20-debian12 AS runner
FROM --platform=linux/amd64 node:20-alpine AS runner
RUN apk add --no-cache \
    udev \
    ttf-freefont \
    chromium
WORKDIR /app


ENV NODE_ENV production
ENV PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser

# ENV NEXT_TELEMETRY_DISABLED 1

COPY --from=builder /app/next.config.mjs ./
COPY --from=builder /app/public ./public
COPY --from=builder /app/package.json ./package.json

COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/.next/static ./.next/static

EXPOSE 10000
ENV PORT 10000

CMD ["server.js"]