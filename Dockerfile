# Multi-stage Dockerfile for Next.js 15 (Node 20)
# Build stage
FROM node:20-alpine AS builder

# Install OS deps if needed (git for postinstall, optional)
RUN apk add --no-cache libc6-compat

WORKDIR /app

# Leverage cached deps
COPY package.json package-lock.json* .npmrc* ./
RUN npm ci --omit=optional

# Copy source
COPY . .

# Ensure production build
ENV NODE_ENV=production

# Build Next.js
RUN npm run build

# Runtime stage
FROM node:20-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production

# Create non-root user for security
RUN addgroup -S nextjs && adduser -S nextjs -G nextjs

# Copy only necessary artifacts from builder
COPY --from=builder /app/package.json ./package.json
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/.next ./.next
COPY --from=builder /app/public ./public
COPY --from=builder /app/next.config.ts ./next.config.ts
COPY --from=builder /app/next-env.d.ts ./next-env.d.ts

# Expose Next.js port
EXPOSE 3000

# Healthcheck (optional)
HEALTHCHECK --interval=30s --timeout=3s --retries=3 CMD wget -qO- http://127.0.0.1:3000 || exit 1

# Run as non-root
USER nextjs

# Start the server
CMD ["npm", "run", "start"]