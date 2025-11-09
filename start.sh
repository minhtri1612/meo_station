#!/bin/sh
set -e

echo "🔄 Waiting for database before running migrations..."
ATTEMPTS=0
MAX_ATTEMPTS=30

until prisma migrate deploy --schema=/app/prisma/schema.prisma; do
  ATTEMPTS=$((ATTEMPTS + 1))
  if [ "$ATTEMPTS" -ge "$MAX_ATTEMPTS" ]; then
    echo "❌ Prisma migrate still failing after $MAX_ATTEMPTS attempts"
    exit 1
  fi
  echo "⚠️  Prisma migrate failed (attempt $ATTEMPTS); retrying in 5s..."
  sleep 5
done
echo "✅ Prisma migrations complete"

echo "🌱 Seeding database..."
if tsx /app/prisma/seed.ts; then
  echo "✅ Database seeded"
else
  echo "⚠️  Database seeding failed; continuing startup"
fi

echo "🚀 Starting Next.js server..."
exec node server.js
