#!/bin/sh
# Skip migrations for now since database schema already exists

echo "Starting Next.js server directly..."
# Start the Next.js server
exec node server.js