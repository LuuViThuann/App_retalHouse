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

// 🔥 FIX: Property type normalization
const normalizePropertyType = (propertyType) => {
  const typeMap = {
    'Căn hộ chung cư': 'Apartment',
    'apartment': 'Apartment',
    'Nhà riêng': 'House',
    'house': 'House',
    'Nhà trọ/Phòng trọ': 'Room',
    'room': 'Room',
    'Biệt thự': 'Villa',
    'villa': 'Villa',
    'Văn phòng': 'Office',
    'office': 'Office',
    'Mặt bằng kinh doanh': 'Shop',
    'shop': 'Shop',
    'Đất nền': 'Land',
    'land': 'Land',
  };
  
  const normalized = typeMap[propertyType] || typeMap[propertyType?.toLowerCase()];
  return normalized || propertyType || 'Unknown';
};

async function createRentalsIndex() {
  try {
    const indexExists = await elasticClient.indices.exists({ index: 'rentals' });
    
    if (indexExists) {
      console.log('✅ Rentals index already exists');
      
      const shouldUpdate = await promptUpdateMapping();
      if (!shouldUpdate) {
        return;
      }
      
      console.log('🔄 Updating index mappings...');
      await elasticClient.indices.close({ index: 'rentals' });
      
      await elasticClient.indices.putMapping({
        index: 'rentals',
        body: {
          properties: {
            title: { 
              type: 'text',
              analyzer: 'standard',
              fields: {
                keyword: { type: 'keyword' }
              }
            },
            price: { type: 'float' },
            location: { 
              type: 'text',
              analyzer: 'standard',
              fields: {
                keyword: { type: 'keyword' }
              }
            },
            coordinates: {
              type: 'geo_point'
            },
            // 🔥 FIX: Đảm bảo propertyType là keyword (case-sensitive)
            propertyType: { 
              type: 'keyword',
              normalizer: 'lowercase_normalizer' // Thêm normalizer
            },
            status: { type: 'keyword' },
            area: { type: 'float' },
            createdAt: { type: 'date' },
            images: { type: 'keyword' },
            geocodingStatus: { type: 'keyword' },
          },
        },
      });
      
      await elasticClient.indices.open({ index: 'rentals' });
      console.log('✅ Index mappings updated successfully');
    } else {
      console.log('🔨 Creating rentals index...');
      
      await elasticClient.indices.create({
        index: 'rentals',
        body: {
          settings: {
            number_of_shards: 1,
            number_of_replicas: 0,
            analysis: {
              analyzer: {
                vietnamese_analyzer: {
                  type: 'standard',
                  stopwords: '_vietnamese_'
                }
              },
              // 🔥 FIX: Thêm normalizer để search case-insensitive
              normalizer: {
                lowercase_normalizer: {
                  type: 'custom',
                  filter: ['lowercase']
                }
              }
            }
          },
          mappings: {
            properties: {
              title: { 
                type: 'text',
                analyzer: 'vietnamese_analyzer',
                fields: {
                  keyword: { type: 'keyword' }
                }
              },
              price: { type: 'float' },
              location: { 
                type: 'text',
                analyzer: 'vietnamese_analyzer',
                fields: {
                  keyword: { type: 'keyword' }
                }
              },
              coordinates: {
                type: 'geo_point'
              },
              propertyType: { 
                type: 'keyword',
                normalizer: 'lowercase_normalizer'
              },
              status: { type: 'keyword' },
              area: { type: 'float' },
              createdAt: { type: 'date' },
              images: { type: 'keyword' },
              geocodingStatus: { type: 'keyword' },
            },
          },
        },
      });
      
      console.log('✅ Rentals index created successfully');
    }
  } catch (err) {
    console.error('❌ Error managing rentals index:', err.message);
    throw err;
  }
}

async function promptUpdateMapping() {
  const readline = require('readline').createInterface({
    input: process.stdin,
    output: process.stdout
  });

  return new Promise((resolve) => {
    readline.question('Do you want to update index mappings? (y/n): ', (answer) => {
      readline.close();
      resolve(answer.toLowerCase() === 'y');
    });
  });
}

async function syncAllRentals() {
  try {
    await mongoose.connect(process.env.MONGODB_URI, {
      useNewUrlParser: true,
      useUnifiedTopology: true,
    });
    console.log('✅ Connected to MongoDB');

    const rentals = await Rental.find().lean();
    console.log(`📊 Found ${rentals.length} rentals to sync`);

    let successCount = 0;
    let errorCount = 0;
    const errors = [];

    const bulkBody = [];
    
    for (const rental of rentals) {
      try {
        let coordinates = null;
        if (rental.location?.coordinates?.coordinates) {
          const [lon, lat] = rental.location.coordinates.coordinates;
          if (lon !== 0 || lat !== 0) {
            coordinates = { lat, lon };
          }
        }

        // 🔥 FIX: Normalize property type
        const normalizedPropertyType = normalizePropertyType(rental.propertyType);
        
        console.log(`📝 Rental ${rental._id}: ${rental.propertyType} → ${normalizedPropertyType}`);

        const doc = {
          title: rental.title || '',
          price: parseFloat(rental.price) || 0,
          location: rental.location?.short || rental.location?.fullAddress || '',
          coordinates: coordinates,
          propertyType: normalizedPropertyType, // ← Dùng normalized value
          status: rental.status || 'available',
          area: parseFloat(rental.area?.total) || 0,
          createdAt: rental.createdAt || new Date(),
          images: rental.images || [],
          geocodingStatus: rental.geocodingStatus || 'pending',
        };

        bulkBody.push(
          { index: { _index: 'rentals', _id: rental._id.toString() } },
          doc
        );

        successCount++;
      } catch (err) {
        errorCount++;
        errors.push({
          rentalId: rental._id,
          error: err.message
        });
        console.error(`❌ Error preparing rental ${rental._id}:`, err.message);
      }
    }

    if (bulkBody.length > 0) {
      console.log(`📤 Syncing ${successCount} rentals to Elasticsearch...`);
      
      const bulkResponse = await elasticClient.bulk({
        refresh: true,
        body: bulkBody,
      });

      if (bulkResponse.errors) {
        console.error('⚠️ Some bulk operations failed:');
        bulkResponse.items.forEach((item, i) => {
          if (item.index?.error) {
            console.error(`   - Document ${i}: ${item.index.error.reason}`);
          }
        });
      }
    }

    console.log('\n📋 Sync Summary:');
    console.log(`   ✅ Success: ${successCount}`);
    console.log(`   ❌ Errors: ${errorCount}`);
    
    if (errors.length > 0) {
      console.log('\n⚠️ Failed rentals:');
      errors.forEach(({ rentalId, error }) => {
        console.log(`   - ${rentalId}: ${error}`);
      });
    }

    console.log('\n✅ Sync completed');
    process.exit(0);
  } catch (err) {
    console.error('❌ Fatal error during sync:', err);
    process.exit(1);
  }
}

async function resetIndex() {
  try {
    const indexExists = await elasticClient.indices.exists({ index: 'rentals' });
    
    if (indexExists) {
      console.log('🗑️  Deleting existing index...');
      await elasticClient.indices.delete({ index: 'rentals' });
      console.log('✅ Index deleted');
    }
    
    await createRentalsIndex();
    console.log('✅ Index reset complete');
  } catch (err) {
    console.error('❌ Error resetting index:', err.message);
    throw err;
  }
}

const args = process.argv.slice(2);
const command = args[0];

(async () => {
  try {
    if (command === 'reset') {
      console.log('🔄 Resetting Elasticsearch index...\n');
      await resetIndex();
      await syncAllRentals();
    } else {
      console.log('🚀 Starting Elasticsearch sync...\n');
      await createRentalsIndex();
      await syncAllRentals();
    }
  } catch (err) {
    console.error('❌ Failed to complete operation:', err);
    process.exit(1);
  }
})();