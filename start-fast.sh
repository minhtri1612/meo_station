#!/bin/sh
set -e

echo "🚀 Meo Stationery - FAST STARTUP"

# Quick database check
if [ -n "$DATABASE_URL" ]; then
    echo "🔄 Deploying migrations (pre-installed Prisma)..."
    # Use globally installed Prisma - NO DOWNLOAD!
    prisma migrate deploy --schema=./prisma/schema.prisma
    echo "✅ Migrations complete"
else
    echo "⚠️  Skipping migrations (no DATABASE_URL)"
fi

echo "🎯 Starting Next.js..."
exec "$@"
