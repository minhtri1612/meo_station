import { PrismaClient } from '@prisma/client'

const prisma = new PrismaClient()

const products = [
  // Category A - Notebooks/Journals
  { id: 'A', name: 'Premium Spiral Notebook', price: 15000, description: 'High-quality spiral notebook perfect for students and professionals', quantity: 50 },
  
  // Category B - Pens & Writing
  { id: 'B', name: 'Gel Pen Set', price: 25000, description: 'Smooth writing gel pens in multiple colors', quantity: 100 },
  
  // Category C - Art Supplies
  { id: 'C', name: 'Colored Pencil Set', price: 45000, description: 'Professional grade colored pencils for artists', quantity: 30 },
  
  // Category D - Office Supplies
  { id: 'D', name: 'Document Organizer', price: 35000, description: 'Keep your documents organized and accessible', quantity: 25 },
  
  // Category E - School Supplies
  { id: 'E', name: 'Student Starter Kit', price: 55000, description: 'Complete kit for students with essential supplies', quantity: 40 },
  
  // Category F - Planning & Organization
  { id: 'F', name: 'Weekly Planner', price: 28000, description: 'Stay organized with this beautiful weekly planner', quantity: 35 },
  
  // Category G - Craft Supplies
  { id: 'G', name: 'Craft Paper Bundle', price: 20000, description: 'Assorted craft papers for all your creative projects', quantity: 60 },
  
  // Category H - Highlighters
  { id: 'H', name: 'Highlighter Set', price: 18000, description: 'Bright highlighters for studying and note-taking', quantity: 80 },
  
  // Category J - Journals
  { id: 'J', name: 'Leather Bound Journal', price: 65000, description: 'Elegant leather journal for special thoughts', quantity: 20 },
  
  // Category K - Erasers & Correction
  { id: 'K', name: 'Eraser Collection', price: 12000, description: 'Various erasers for different needs', quantity: 90 },
  
  // Category L - Labels & Stickers
  { id: 'L', name: 'Label Maker Kit', price: 42000, description: 'Create professional labels for organization', quantity: 15 },
  
  // Category M - Markers
  { id: 'M', name: 'Permanent Marker Set', price: 32000, description: 'Long-lasting permanent markers for various surfaces', quantity: 45 },
  
  // Category N - Notebooks
  { id: 'N', name: 'Hardcover Notebook', price: 38000, description: 'Durable hardcover notebook for important notes', quantity: 30 },
  
  // Category O - Office Accessories
  { id: 'O', name: 'Desk Organizer Set', price: 48000, description: 'Complete desk organization solution', quantity: 25 },
  
  // Category P - Paper Products
  { id: 'P', name: 'Premium Paper Stack', price: 22000, description: 'High-quality paper for printing and writing', quantity: 70 }
]

async function main() {
  console.log('🌱 Seeding database...')
  
  // Clear existing products
  await prisma.product.deleteMany()
  console.log('🗑️  Cleared existing products')
  
  // Create products
  for (const product of products) {
    await prisma.product.create({
      data: product
    })
    console.log(`✅ Created product: ${product.name}`)
  }
  
  console.log('🎉 Seeding completed!')
  console.log(`📦 Created ${products.length} products`)
}

main()
  .catch((e) => {
    console.error('❌ Error seeding database:', e)
    process.exit(1)
  })
  .finally(async () => {
    await prisma.$disconnect()
  })
