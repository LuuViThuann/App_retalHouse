// services/poi-service.js - TỐI ƯU HÓA
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
  },
  VETERINARY: {
    name: 'Thú y',
    icon: '🐶',           // hoặc 🩺 nếu muốn nhấn mạnh y tế
    tags: ['veterinary'],
    query: 'node["amenity"~"veterinary"]'
  },
  FUEL: {
    name: 'Cây xăng',
    icon: '⛽',
    tags: ['fuel'],
    query: 'node["amenity"~"fuel"]'
  },
  HAIRDRESSER: {
    name: 'Tiệm cắt tóc',
    icon: '✂️',
    tags: ['hairdresser'],
    query: 'node["shop"~"hairdresser"]'
  },
  CAR_REPAIR: {
    name: 'Sửa xe',
    icon: '🔧',
    tags: ['car_repair'],
    query: 'node["shop"~"car_repair"]'
  },
};

/**
 * 🔍 Overpass API Service - Lấy POI từ OpenStreetMap
 * ✅ TỐI ƯU HÓA: Xử lý lỗi 504, giới hạn POI, retry logic 
 */
class POIService {
  constructor() {
    this.overpassUrl = 'https://overpass-api.de/api/interpreter';
    this.cache = new Map();
    this.cacheDuration = 1000 * 60 * 30; // 30 minutes
    this.maxPOIsPerCategory = 50; // ✅ GIỚI HẠN 50 POI/category
    this.requestTimeout = 45000; // ✅ TIMEOUT 45s
    this.maxRetries = 2; // ✅ RETRY 2 lần nếu lỗi
  }

  /**
   * 🌍 Lấy POI theo category và vị trí
   * ✅ CẬP NHẬT: Retry logic + Timeout handling + POI limiting
   */
  async getPOIsByCategory(latitude, longitude, category, radiusKm = 5) {
    const cacheKey = `${category}_${latitude}_${longitude}_${radiusKm}`;

    // Check cache
    if (this.cache.has(cacheKey)) {
      const cached = this.cache.get(cacheKey);
      if (Date.now() - cached.timestamp < this.cacheDuration) {
        console.log(`✅ [POI-CACHE] Using cached data for ${category} (${cached.data.length} POIs)`);
        return cached.data;
      }
    }

    const categoryConfig = POI_CATEGORIES[category];
    if (!categoryConfig) {
      throw new Error(`Invalid category: ${category}`);
    }

    let lastError;

    // ✅ RETRY LOGIC: Thử lại tối đa maxRetries lần
    for (let attempt = 1; attempt <= this.maxRetries + 1; attempt++) {
      try {
        const radiusMeters = radiusKm * 1000;

        // ✅ CẬP NHẬT: Thêm [maxsize:...] để giới hạn response size
        const query = `
          [out:json][timeout:30][maxsize:536870912];
          (
            ${categoryConfig.query}(around:${radiusMeters},${latitude},${longitude});
          );
          out center;
        `;

        console.log(`🔍 [POI-SERVICE] Fetching ${category} (Attempt ${attempt}/${this.maxRetries + 1}) near (${latitude}, ${longitude}), radius: ${radiusKm}km`);

        const response = await axios.post(
          this.overpassUrl,
          `data=${encodeURIComponent(query)}`,
          {
            headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
            timeout: this.requestTimeout
          }
        );

        const pois = this.parsePOIResponse(response.data, category, latitude, longitude);

        // ✅ GIỚI HẠN POIs: Lấy 50 gần nhất
        const limitedPOIs = pois
          .sort((a, b) => a.distanceFromUser - b.distanceFromUser)
          .slice(0, this.maxPOIsPerCategory);

        // Cache result
        this.cache.set(cacheKey, {
          data: limitedPOIs,
          timestamp: Date.now()
        });

        console.log(`✅ [POI-SERVICE] Found ${pois.length} ${category} POIs, limited to ${limitedPOIs.length}`);
        return limitedPOIs;

      } catch (error) {
        lastError = error;

        if (error.response?.status === 504 || error.code === 'ECONNABORTED') {
          console.warn(`⚠️ [POI-SERVICE] Attempt ${attempt} failed (${error.response?.status || error.code}), retrying...`);

          // ✅ BACKOFF: Chờ 2s trước khi retry
          if (attempt <= this.maxRetries) {
            await new Promise(resolve => setTimeout(resolve, 2000));
            continue;
          }
        } else {
          // Lỗi khác, không retry
          break;
        }
      }
    }

    // ✅ FALLBACK: Nếu tất cả retry thất bại, trả về array rỗng thay vì throw error
    console.error(`❌ [POI-SERVICE] Error fetching ${category} after ${this.maxRetries + 1} attempts:`, lastError.message);
    return []; // Trả về array rỗng thay vì crash
  }

  /**
   * 📊 Parse Overpass API response
   */
  parsePOIResponse(data, category, userLat, userLon) {
    if (!data || !data.elements || data.elements.length === 0) {
      return [];
    }

    const categoryConfig = POI_CATEGORIES[category];

    return data.elements
      .filter(element => element.lat && element.lon) // ✅ Filter invalid coords
      .map(element => {
        const poiLat = element.lat;
        const poiLon = element.lon;

        // 🔥 TÍNH KHOẢNG CÁCH TỪ USER ĐẾN POI
        const distanceFromUser = this.calculateDistance(
          userLat,
          userLon,
          poiLat,
          poiLon
        );

        return {
          id: `poi_${category}_${element.id}`,
          osmId: element.id,
          category: category,
          categoryName: categoryConfig.name,
          categoryIcon: categoryConfig.icon,
          name: element.tags?.name || `${categoryConfig.name} (không tên)`,
          latitude: poiLat,
          longitude: poiLon,
          tags: element.tags || {},
          distanceFromUser: distanceFromUser,
          address: this.buildAddress(element.tags)
        };
      });
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
   * 🔥 Filter rentals based on POI distance
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
          distance: this.formatDistance(distance)
        }
      };
    }).filter(r => r.withinRadius);
  }

  /**
   * 🔥 Filter rentals by multiple POI categories
   */
  filterRentalsByMultiplePOIs(selectedCategories, poiData, rentals, radiusKm = 3) {
    const filteredRentals = [];
    const processedRentalIds = new Set();

    // 🔥 BƯỚC 1: THU THẬP TẤT CẢ POI TỪ CÁC CATEGORIES ĐÃ CHỌN
    const allPOIs = [];

    for (const categoryId of selectedCategories) {
      const pois = poiData[categoryId] || [];
      allPOIs.push(...pois);
    }

    console.log(`📊 [FILTER-POI] Total POIs from ${selectedCategories.length} categories: ${allPOIs.length}`);

    // ✅ CẬP NHẬT: Không còn lấy 100 POI, mà dùng tất cả POI đã giới hạn
    // (mỗi category tối đa 50 POI, vậy tối đa 100 POI nếu 2 categories)
    allPOIs.sort((a, b) => a.distanceFromUser - b.distanceFromUser);

    console.log(`✂️ [FILTER-POI] Using ${allPOIs.length} POIs for filtering`);

    // 🔥 BƯỚC 2: XỬ LÝ VỚI TẤT CẢ POI
    for (const poi of allPOIs) {
      const rentalsNearPOI = this.filterRentalsByPOIDistance(poi, rentals, radiusKm);

      for (const rental of rentalsNearPOI) {
        if (!processedRentalIds.has(rental._id.toString())) {
          rental.nearestPOIs = [{
            name: poi.name,
            category: poi.categoryName,
            icon: poi.categoryIcon,
            distance: this.formatDistance(rental.distanceFromPOI)
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
              distance: this.formatDistance(rental.distanceFromPOI)
            });
          }
        }
      }
    }

    // ✅ Sort rentals theo khoảng cách gần nhất
    return filteredRentals.sort((a, b) => {
      const minDistA = Math.min(...(a.nearestPOIs?.map(p => parseFloat(p.distance)) || [Infinity]));
      const minDistB = Math.min(...(b.nearestPOIs?.map(p => parseFloat(p.distance)) || [Infinity]));
      return minDistA - minDistB;
    });
  }

  /**
   * 🔥 FORMAT DISTANCE
   */
  formatDistance(distanceKm) {
    if (distanceKm < 1) {
      return (distanceKm * 1000).toFixed(0); // Trả về mét (string)
    }
    return distanceKm.toFixed(2); // Trả về km (string)
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