require('dotenv').config();
const mongoose = require('mongoose');
const { Client } = require('@elastic/elasticsearch');
const Rental = require('./models/Rental');

const elasticClient = new Client({
  node: process.env.ELASTICSEARCH_URL || 'http://localhost:9200',
  maxRetries: 3,
  requestTimeout: 30000,
  sniffOnStart: false,
  sniffOnConnectionFault: false,
});

const propertyTypeMap = {
  'Căn hộ chung cư': 'Apartment',
  'Nhà riêng': 'House',
  'Nhà trọ/Phòng trọ': 'Room',
  'Biệt thự': 'Villa',
  'Văn phòng': 'Office',
  'Mặt bằng kinh doanh': 'Shop',
};

async function createRentalsIndex() {
  try {
    const exists = await elasticClient.indices.exists({ index: 'rentals' });
    if (!exists) {
      await elasticClient.indices.create({
        index: 'rentals',
        body: {
          mappings: {
            properties: {
              title: { type: 'text' },
              price: { type: 'float' },
              location: { type: 'text' },
              propertyType: { type: 'keyword' },
              status: { type: 'keyword' },
              area: { type: 'float' },
              createdAt: { type: 'date' },
              images: { type: 'keyword' },
            },
          },
        },
        headers: {
          Accept: 'application/json',
          'Content-Type': 'application/json',
        },
      });
      console.log('Created rentals index');
    } else {
      console.log('Rentals index already exists');
    }
  } catch (err) {
    console.error('Error creating rentals index:', err);
    throw err;
  }
}

async function syncAllRentals() {
  try {
    await mongoose.connect(process.env.MONGODB_URI, {
      useNewUrlParser: true,
      useUnifiedTopology: true,
    });
    console.log('Connected to MongoDB');

    const rentals = await Rental.find();
    console.log(`Found ${rentals.length} rentals to sync`);

    for (const rental of rentals) {
      const response = await elasticClient.index({
        index: 'rentals',
        id: rental._id.toString(),
        body: {
          title: rental.title,
          price: parseFloat(rental.price) || 0,
          location: rental.location.short,
          propertyType: propertyTypeMap[rental.propertyType] || rental.propertyType,
          status: rental.status,
          area: parseFloat(rental.area.total) || 0,
          createdAt: rental.createdAt,
          images: rental.images || [],
        },
        headers: {
          Accept: 'application/json',
          'Content-Type': 'application/json',
        },
      });
      console.log(`Synced rental: ${rental._id}`, response);
    }

    console.log('Sync completed');
    process.exit(0);
  } catch (err) {
    console.error('Error syncing rentals:', err);
    process.exit(1);
  }
}
// Execute index creation and then sync rentals
createRentalsIndex()
  .then(() => syncAllRentals())
  .catch((err) => {
    console.error('Failed to initialize:', err);
    process.exit(1);
  });