# Meo Stationery 📝

A modern e-commerce platform for stationery products built with Next.js, Prisma, and PostgreSQL.

## Features

- 🛍️ Product catalog with categories
- 🛒 Shopping cart functionality
- 📦 Order management
- 👤 User management
- 💳 Payment integration with VNPay
- 📱 Responsive design with Tailwind CSS
- 🎨 Modern UI with Radix UI components

## Quick Setup

Run the automated setup script:

```bash
./setup.sh
```

Or follow the manual setup steps below.

## Manual Setup

### Prerequisites

- Node.js 18+ 
- PostgreSQL database
- npm or yarn

### Installation

1. Clone the repository and install dependencies:

```bash
npm install
```

2. Set up environment variables:

```bash
cp .env.example .env.local
```

Edit `.env.local` with your actual values:

```env
DATABASE_URL="postgresql://username:password@localhost:5432/meo_stationery?schema=public"
VNP_TMN_CODE=your_vnpay_tmn_code
VNP_HASH_SECRET=your_vnpay_hash_secret
NEXTAUTH_URL=http://localhost:3000
NEXTAUTH_SECRET=your-secret-key-here
```

3. Set up the database:

```bash
# Generate Prisma client
npx prisma generate

# Create/update database schema
npx prisma db push

# Seed with sample data (optional)
npx tsx prisma/seed.ts
```

4. Start the development server:

```bash
npm run dev
```

Open [http://localhost:3000](http://localhost:3000) to see the application.

## Database Setup

This project uses PostgreSQL with Prisma ORM. Make sure you have:

1. PostgreSQL installed and running
2. A database created for the project
3. Updated the `DATABASE_URL` in your `.env.local` file

### Database Schema

The project includes these main models:
- `User` - Customer information
- `Product` - Stationery products
- `Order` - Customer orders
- `OrderItem` - Items within orders
- `Payment` - Payment records
- `Address` - Customer addresses

## Development

### Local Development

```bash
npm run dev
```

### Docker Development

Build and run with Docker:

```bash
# Build the Docker image
npm run docker:build

# Run the container
npm run docker:run

# Or use docker-compose for easier management
npm run docker:compose
```

The application will be available at http://localhost:3000

### Database Information

This project uses SQLite with Prisma ORM for local development. The database file is stored at `prisma/dev.db`.

For production, you can switch to PostgreSQL by updating the schema and environment variables.

### Database Schema

The project includes these main models:
- `User` - Customer information
- `Product` - Stationery products
- `Order` - Customer orders
- `OrderItem` - Items within orders
- `Payment` - Payment records
- `Address` - Customer addresses

## Docker Deployment

### Building the Image

```bash
docker build -t meo-stationery:latest .
```

### Running with Docker

```bash
docker run -p 3000:3000 meo-stationery:latest
```

### Using Docker Compose

```bash
docker-compose up -d
```

To stop:

```bash
docker-compose down
```
