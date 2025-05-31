# syntax=docker/dockerfile:1

# Base image
FROM node:20-alpine AS base

WORKDIR /app

# Install dependencies (only what's needed for production build)
FROM base AS deps

# Install system dependencies
RUN apk add --no-cache libc6-compat bash

# Copy dependency-related files first
COPY package.json package-lock.json ./
COPY prisma ./prisma

# Install dependencies
RUN npm install --frozen-lockfile

# Generate Prisma client
RUN npx prisma generate

# Build the app
FROM base AS builder

# Copy installed node_modules and prisma client
COPY --from=deps /app/node_modules ./node_modules
COPY --from=deps /app/prisma ./prisma

# Copy the rest of the application
COPY . .

# Build the app using npm
RUN npm run build

# Final runtime image
FROM base AS runner

# Optional: create a non-root user
RUN addgroup --system --gid 1001 nodejs \
  && adduser --system --uid 1001 nextjs

WORKDIR /app

# Set environment vars
ENV NODE_ENV=production
ENV PORT=3000
ENV HOSTNAME="0.0.0.0"

# Copy built app from builder
COPY --from=builder /app/public ./public
COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/.next/static ./.next/static
COPY --from=builder /app/.env ./.env  # Optional: only if you need env vars

USER nextjs

EXPOSE 3000
CMD ["node", "server.js"]
