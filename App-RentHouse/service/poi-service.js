// services/poi-service.js - CẬP NHẬT với tính năng lọc khoảng cách
const axios = require('axios');

/**
 * 🗺️ POI Categories - Các danh mục địa điểm quan trọng
 */
const POI_CATEGORIES = {
  EDUCATION: {
    name: 'Giáo dục',
    icon: '🎓',
    tags: ['school', 'university', 'college', 'kindergarten'],
    query: 'node["amenity"~"school|university|college|kindergarten"]'
  },
  HOSPITAL: {
    name: 'Y tế',
    icon: '🏥',
    tags: ['hospital', 'clinic', 'doctors', 'pharmacy'],
    query: 'node["amenity"~"hospital|clinic|doctors|pharmacy"]'
  },
  TRANSPORT: {
    name: 'Giao thông',
    icon: '🚌',
    tags: ['bus_station', 'railway_station', 'subway_entrance'],
    query: 'node["amenity"~"bus_station|railway_station|subway_entrance"]'
  },
  SHOPPING: {
    name: 'Mua sắm',
    icon: '🛒',
    tags: ['supermarket', 'mall', 'marketplace'],
    query: 'node["shop"~"supermarket|mall|marketplace"]'
  },
  RESTAURANT: {
    name: 'Ăn uống',
    icon: '🍽️',
    tags: ['restaurant', 'cafe', 'fast_food'],
    query: 'node["amenity"~"restaurant|cafe|fast_food"]'
  },
  PARK: {
    name: 'Công viên',
    icon: '🌳',
    tags: ['park', 'garden'],
    query: 'node["leisure"~"park|garden"]'
  },
  BANK: {
    name: 'Ngân hàng',
    icon: '🏦',
    tags: ['bank', 'atm'],
    query: 'node["amenity"~"bank|atm"]'
  },
  GYM: {
    name: 'Thể thao',
    icon: '💪',
    tags: ['fitness_centre', 'sports_centre'],
    query: 'node["leisure"~"fitness_centre|sports_centre"]'
  }
};

/**
 * 🔍 Overpass API Service - Lấy POI từ OpenStreetMap
 */
class POIService {
  constructor() {
    this.overpassUrl = 'https://overpass-api.de/api/interpreter';
    this.cache = new Map();
    this.cacheDuration = 1000 * 60 * 30; // 30 minutes
  }

  /**
   * 🌍 Lấy POI theo category và vị trí
   */
  async getPOIsByCategory(latitude, longitude, category, radiusKm = 5) {
    try {
      const cacheKey = `${category}_${latitude}_${longitude}_${radiusKm}`;
      
      // Check cache
      if (this.cache.has(cacheKey)) {
        const cached = this.cache.get(cacheKey);
        if (Date.now() - cached.timestamp < this.cacheDuration) {
          console.log(`✅ [POI-CACHE] Using cached data for ${category}`);
          return cached.data;
        }
      }

      const categoryConfig = POI_CATEGORIES[category];
      if (!categoryConfig) {
        throw new Error(`Invalid category: ${category}`);
      }

      const radiusMeters = radiusKm * 1000;

      const query = `
        [out:json][timeout:25];
        (
          ${categoryConfig.query}(around:${radiusMeters},${latitude},${longitude});
        );
        out center;
      `;

      console.log(`🔍 [POI-SERVICE] Fetching ${category} near (${latitude}, ${longitude}), radius: ${radiusKm}km`);

      const response = await axios.post(
        this.overpassUrl,
        `data=${encodeURIComponent(query)}`,
        {
          headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
          timeout: 30000
        }
      );

      const pois = this.parsePOIResponse(response.data, category);

      // Cache result
      this.cache.set(cacheKey, {
        data: pois,
        timestamp: Date.now()
      });

      console.log(`✅ [POI-SERVICE] Found ${pois.length} ${category} POIs`);
      return pois;

    } catch (error) {
      console.error(`❌ [POI-SERVICE] Error fetching ${category}:`, error.message);
      return [];
    }
  }

  /**
   * 📊 Parse Overpass API response
   */
  parsePOIResponse(data, category) {
    if (!data || !data.elements || data.elements.length === 0) {
      return [];
    }

    const categoryConfig = POI_CATEGORIES[category];

    return data.elements.map(element => ({
      id: `poi_${category}_${element.id}`,
      osmId: element.id,
      category: category,
      categoryName: categoryConfig.name,
      categoryIcon: categoryConfig.icon,
      name: element.tags?.name || `${categoryConfig.name} (không tên)`,
      latitude: element.lat,
      longitude: element.lon,
      tags: element.tags || {},
      distance: null,
      address: this.buildAddress(element.tags)
    })).filter(poi => poi.latitude && poi.longitude);
  }

  /**
   * 🏠 Build address from OSM tags
   */
  buildAddress(tags) {
    const parts = [];
    if (tags['addr:housenumber']) parts.push(tags['addr:housenumber']);
    if (tags['addr:street']) parts.push(tags['addr:street']);
    if (tags['addr:district']) parts.push(tags['addr:district']);
    if (tags['addr:city']) parts.push(tags['addr:city']);
    return parts.join(', ') || 'Không có địa chỉ';
  }

  /**
   * 🎯 Lấy tất cả POI categories gần vị trí
   */
  async getAllPOIsNearby(latitude, longitude, radiusKm = 5) {
    try {
      const results = {};
      const categories = Object.keys(POI_CATEGORIES);

      console.log(`🌍 [POI-SERVICE] Fetching all categories near (${latitude}, ${longitude})`);

      const promises = categories.map(async (category) => {
        const pois = await this.getPOIsByCategory(latitude, longitude, category, radiusKm);
        results[category] = pois;
      });

      await Promise.all(promises);

      const totalPOIs = Object.values(results).reduce((sum, pois) => sum + pois.length, 0);
      console.log(`✅ [POI-SERVICE] Total POIs found: ${totalPOIs}`);

      return results;

    } catch (error) {
      console.error('❌ [POI-SERVICE] Error fetching all POIs:', error.message);
      return {};
    }
  }

  /**
   * 🧮 Haversine formula - Calculate distance between 2 coordinates
   */
  calculateDistance(lat1, lon1, lat2, lon2) {
    const R = 6371; // Earth radius in km
    const dLat = this.toRadians(lat2 - lat1);
    const dLon = this.toRadians(lon2 - lon1);

    const a =
      Math.sin(dLat / 2) * Math.sin(dLat / 2) +
      Math.cos(this.toRadians(lat1)) *
      Math.cos(this.toRadians(lat2)) *
      Math.sin(dLon / 2) *
      Math.sin(dLon / 2);

    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return R * c;
  }

  toRadians(degrees) {
    return degrees * (Math.PI / 180);
  }

  /**
   * 🔥 CẬP NHẬT: Filter rentals based on POI distance
   * @param {Object} poi - POI object
   * @param {Array} rentals - Array of rentals
   * @param {number} radiusKm - Distance radius in km
   * @returns {Array} Rentals within the specified distance from POI
   */
  filterRentalsByPOIDistance(poi, rentals, radiusKm = 3) {
    return rentals.map(rental => {
      const rentalLat = rental.location?.coordinates?.coordinates?.[1] || 0;
      const rentalLon = rental.location?.coordinates?.coordinates?.[0] || 0;

      if (rentalLat === 0 || rentalLon === 0) {
        return { ...rental, distanceFromPOI: Infinity, withinRadius: false };
      }

      const distance = this.calculateDistance(
        poi.latitude,
        poi.longitude,
        rentalLat,
        rentalLon
      );

      return {
        ...rental,
        distanceFromPOI: distance,
        withinRadius: distance <= radiusKm,
        nearbyPOI: {
          name: poi.name,
          category: poi.categoryName,
          icon: poi.categoryIcon,
          distance: distance.toFixed(2)
        }
      };
    }).filter(r => r.withinRadius); // Chỉ trả về rentals trong khoảng cách
  }

  /**
   * 🔥 CẬP NHẬT: Filter rentals by multiple POI categories
   * @param {Array} selectedCategories - Array of category IDs
   * @param {Object} poiData - Object with category => POIs mapping
   * @param {Array} rentals - Array of rentals
   * @param {number} radiusKm - Distance radius in km
   * @returns {Array} Rentals within distance of ANY selected POI
   */
  // trong hàm filterRentalsByMultiplePOIs
filterRentalsByMultiplePOIs(selectedCategories, poiData, rentals, radiusKm = 3) {
  const filteredRentals = [];
  const processedRentalIds = new Set();

  for (const categoryId of selectedCategories) {
    const pois = poiData[categoryId] || [];

    for (const poi of pois) {
      const rentalsNearPOI = this.filterRentalsByPOIDistance(poi, rentals, radiusKm);

      for (const rental of rentalsNearPOI) {
        if (!processedRentalIds.has(rental._id.toString())) {
          rental.nearestPOIs = [{
            name: poi.name,
            category: poi.categoryName,
            icon: poi.categoryIcon,
            distance: rental.distanceFromPOI.toFixed(2)
          }];
          
          filteredRentals.push(rental);
          processedRentalIds.add(rental._id.toString());
        } else {
          const existingRental = filteredRentals.find(r => r._id.toString() === rental._id.toString());
          if (existingRental && !existingRental.nearestPOIs.some(p => p.name === poi.name)) {
            existingRental.nearestPOIs.push({
              name: poi.name,
              category: poi.categoryName,
              icon: poi.categoryIcon,
              distance: rental.distanceFromPOI.toFixed(2)
            });
          }
        }
      }
    }
  }

  return filteredRentals.sort((a, b) => {
    const minDistA = Math.min(...(a.nearestPOIs?.map(p => parseFloat(p.distance)) || [Infinity]));
    const minDistB = Math.min(...(b.nearestPOIs?.map(p => parseFloat(p.distance)) || [Infinity]));
    return minDistA - minDistB;
  });
}

  /**
   * 🗑️ Clear cache
   */
  clearCache() {
    this.cache.clear();
    console.log('✅ POI cache cleared');
  }
}

module.exports = {
  POIService,
  POI_CATEGORIES
};