# Use the official Node.js 18 runtime as the base image
FROM node:18-alpine AS base

# Install dependencies only when needed
FROM base AS deps
# Check https://github.com/nodejs/docker-node/tree/b4117f9333da4138b03a546ec926ef50a31506c3#nodealpine to understand why libc6-compat might be needed.
RUN apk add --no-cache libc6-compat
WORKDIR /app

# Install dependencies based on the preferred package manager
COPY package.json package-lock.json* ./
# THAY ĐỔI: Cài đặt TẤT CẢ dependencies (bao gồm cả devDependencies như prisma)
# Sau đó, chúng ta sẽ prune chúng trong bước builder.
RUN npm ci
# THAY ĐỔI: Chỉ cài đặt production dependencies.
# Điều này yêu cầu bạn phải di chuyển 'prisma' từ 'devDependencies' sang 'dependencies' trong package.json
RUN npm ci --only=production

# Rebuild the source code only when needed
FROM base AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .

# Generate Prisma Client
RUN npx prisma generate
# Generate Prisma Client (sử dụng prisma từ node_modules)
RUN ./node_modules/.bin/prisma generate

# THÊM VÀO: Xóa các devDependencies không cần thiết sau khi build
# để giữ cho node_modules gọn nhẹ hơn cho bước tiếp theo.
RUN npm prune --production

# Build the application
RUN npm run build

# Production image, copy all the files and run next
FROM base AS runner
WORKDIR /app

ENV NODE_ENV production
# Uncomment the following line in case you want to disable telemetry during runtime.
# ENV NEXT_TELEMETRY_DISABLED 1

RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs

# Copy the public folder
COPY --from=builder /app/public ./public

# Set the correct permission for prerender cache
RUN mkdir .next
RUN chown nextjs:nodejs .next

# Automatically leverage output traces to reduce image size
# https://nextjs.org/docs/advanced-features/output-file-tracing
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

# Copy Prisma files
COPY --from=builder /app/prisma ./prisma
COPY --from=builder /app/node_modules/.prisma ./node_modules/.prisma

# THAY ĐỔI: Sao chép và cấp quyền cho script khởi động
COPY start.sh ./start.sh
RUN chmod +x ./start.sh

# Change ownership to nextjs user
# Đảm bảo script cũng thuộc sở hữu của user nextjs
RUN chown -R nextjs:nodejs ./prisma ./node_modules/.prisma

USER nextjs

EXPOSE 3000

ENV PORT 3000
# set hostname to localhost
ENV HOSTNAME "0.0.0.0"

# THAY ĐỔI: Sử dụng script khởi động làm ENTRYPOINT
ENTRYPOINT ["./start.sh"]

# server.js is created by next build from the standalone output
# https://nextjs.org/docs/pages/api-reference/next-config-js/output
CMD ["node", "server.js"] # Lệnh này sẽ được truyền cho start.sh
