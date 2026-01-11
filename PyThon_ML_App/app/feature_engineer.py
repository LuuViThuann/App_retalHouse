import pandas as pd
import numpy as np
from sklearn.preprocessing import StandardScaler, LabelEncoder
from datetime import datetime, timedelta
from math import radians, sin, cos, sqrt, atan2

class FeatureEngineer:
    def __init__(self):
        self.price_scaler = StandardScaler()
        self.area_scaler = StandardScaler()
        self.property_encoder = LabelEncoder()
        self.location_encoder = LabelEncoder()
        
    @staticmethod
    def _haversine_distance(lon1, lat1, lon2, lat2):
        """Tính khoảng cách giữa 2 điểm bằng công thức Haversine (km)"""
        try:
            R = 6371  # Earth radius in km
            lat1, lon1, lat2, lon2 = map(radians, [lat1, lon1, lat2, lon2])
            dlat = lat2 - lat1
            dlon = lon2 - lon1
            
            a = sin(dlat/2)**2 + cos(lat1) * cos(lat2) * sin(dlon/2)**2
            c = 2 * atan2(sqrt(a), sqrt(1-a))
            
            return R * c
        except:
            return 0
    
    def extract_user_features(self, interactions_df, user_id):
        """Trích xuất features cho 1 user - bao gồm cả geographic features"""
        user_data = interactions_df[interactions_df['userId'] == user_id]
        
        if len(user_data) == 0:
            return self._get_default_user_features()
        
        features = {}
        
        # ==================== INTERACTION FEATURES ====================
        
        # 1. Interaction counts
        features['total_interactions'] = len(user_data)
        features['view_count'] = len(user_data[user_data['interactionType'] == 'view'])
        features['click_count'] = len(user_data[user_data['interactionType'] == 'click'])
        features['favorite_count'] = len(user_data[user_data['interactionType'] == 'favorite'])
        features['contact_count'] = len(user_data[user_data['interactionType'] == 'contact'])
        
        # 2. Engagement metrics
        features['avg_interaction_score'] = user_data['interactionScore'].mean()
        features['total_interaction_score'] = user_data['interactionScore'].sum()
        features['engagement_rate'] = features['favorite_count'] / max(features['view_count'], 1)
        
        # ==================== PRICE FEATURES ====================
        
        # 3. Price preferences
        if 'price' in user_data.columns:
            features['avg_price_viewed'] = user_data['price'].mean()
            features['min_price_viewed'] = user_data['price'].min()
            features['max_price_viewed'] = user_data['price'].max()
            features['price_std'] = user_data['price'].std() or 0
            features['price_range'] = features['max_price_viewed'] - features['min_price_viewed']
        else:
            features['avg_price_viewed'] = 0
            features['min_price_viewed'] = 0
            features['max_price_viewed'] = 0
            features['price_std'] = 0
            features['price_range'] = 0
        
        # ==================== PROPERTY TYPE FEATURES ====================
        
        # 4. Property type preferences
        if 'propertyType' in user_data.columns:
            property_counts = user_data['propertyType'].value_counts()
            features['preferred_property_type'] = property_counts.index[0] if len(property_counts) > 0 else 'unknown'
            features['property_type_diversity'] = len(property_counts)
        else:
            features['preferred_property_type'] = 'unknown'
            features['property_type_diversity'] = 0
        
        # ==================== LOCATION & GEOGRAPHIC FEATURES ====================
        
        # 5. Location text preferences
        if 'location_text' in user_data.columns:
            location_counts = user_data['location_text'].value_counts()
            features['preferred_location'] = location_counts.index[0] if len(location_counts) > 0 else 'unknown'
            features['location_diversity'] = len(location_counts)
        else:
            features['preferred_location'] = 'unknown'
            features['location_diversity'] = 0
        
        # 🔥 NEW: Geographic features - tính centroid của user
        if 'longitude' in user_data.columns and 'latitude' in user_data.columns:
            valid_coords = user_data[
                (user_data['longitude'] != 0) & 
                (user_data['latitude'] != 0)
            ]
            
            if len(valid_coords) > 0:
                # Centroid location (trung bình vị trí)
                features['user_centroid_longitude'] = float(valid_coords['longitude'].mean())
                features['user_centroid_latitude'] = float(valid_coords['latitude'].mean())
                
                # Location spread (phạm vi tìm kiếm)
                features['location_spread_lon'] = float(valid_coords['longitude'].max() - valid_coords['longitude'].min())
                features['location_spread_lat'] = float(valid_coords['latitude'].max() - valid_coords['latitude'].min())
                
                # Geographic diversity (bao nhiêu khu vực khác nhau)
                features['geographic_diversity'] = float(len(valid_coords))
                
                # Max distance from centroid (phạm vi tìm kiếm max)
                centroid_lon = features['user_centroid_longitude']
                centroid_lat = features['user_centroid_latitude']
                
                max_distance = 0
                for _, row in valid_coords.iterrows():
                    dist = self._haversine_distance(
                        centroid_lon, centroid_lat,
                        row['longitude'], row['latitude']
                    )
                    max_distance = max(max_distance, dist)
                
                features['max_search_radius_km'] = float(max_distance)
            else:
                # No valid coordinates
                features['user_centroid_longitude'] = 0
                features['user_centroid_latitude'] = 0
                features['location_spread_lon'] = 0
                features['location_spread_lat'] = 0
                features['geographic_diversity'] = 0
                features['max_search_radius_km'] = 0
        else:
            features['user_centroid_longitude'] = 0
            features['user_centroid_latitude'] = 0
            features['location_spread_lon'] = 0
            features['location_spread_lat'] = 0
            features['geographic_diversity'] = 0
            features['max_search_radius_km'] = 0
        
        # ==================== AREA FEATURES ====================
        
        # 6. Area preferences
        if 'area' in user_data.columns:
            features['avg_area_viewed'] = user_data['area'].mean()
            features['min_area_viewed'] = user_data['area'].min()
            features['max_area_viewed'] = user_data['area'].max()
            features['area_std'] = user_data['area'].std() or 0
        else:
            features['avg_area_viewed'] = 0
            features['min_area_viewed'] = 0
            features['max_area_viewed'] = 0
            features['area_std'] = 0
        
        # ==================== TIME-BASED FEATURES ====================
        
        # 7. Time-based features
        if 'timestamp' in user_data.columns:
            user_data_copy = user_data.copy()
            user_data_copy['timestamp'] = pd.to_datetime(user_data_copy['timestamp'])
            features['days_since_first_interaction'] = (datetime.now() - user_data_copy['timestamp'].min()).days
            features['days_since_last_interaction'] = (datetime.now() - user_data_copy['timestamp'].max()).days
            features['avg_interactions_per_day'] = len(user_data) / max(features['days_since_first_interaction'], 1)
        else:
            features['days_since_first_interaction'] = 0
            features['days_since_last_interaction'] = 0
            features['avg_interactions_per_day'] = 0
        
        # ==================== RECENT ACTIVITY ====================
        
        # 8. Recent activity (last 7 days)
        if 'timestamp' in user_data.columns:
            user_data_copy = user_data.copy()
            user_data_copy['timestamp'] = pd.to_datetime(user_data_copy['timestamp'])
            recent = user_data_copy[user_data_copy['timestamp'] >= (datetime.now() - timedelta(days=7))]
            features['recent_interactions_7d'] = len(recent)
            features['recent_favorites_7d'] = len(recent[recent['interactionType'] == 'favorite'])
        else:
            features['recent_interactions_7d'] = 0
            features['recent_favorites_7d'] = 0
        
        return features
    
    def extract_item_features(self, rental):
        """Trích xuất features cho 1 bài đăng - bao gồm cả geographic features"""
        features = {}
        
        # ==================== BASIC FEATURES ====================
        
        features['price'] = float(rental.get('price', 0))
        features['area_total'] = float(rental.get('area_total', 0))
        features['area_bedrooms'] = int(rental.get('area_bedrooms', 0))
        features['amenities_count'] = int(rental.get('amenities_count', 0))
        features['furniture_count'] = int(rental.get('furniture_count', 0))
        features['images_count'] = int(rental.get('images_count', 0))
        
        features['propertyType'] = str(rental.get('propertyType', 'unknown'))
        features['location_text'] = str(rental.get('location_short', 'unknown'))
        
        # ==================== CALCULATED FEATURES ====================
        
        # Calculated features
        features['price_per_sqm'] = features['price'] / max(features['area_total'], 1)
        features['has_furniture'] = 1 if features['furniture_count'] > 0 else 0
        features['has_amenities'] = 1 if features['amenities_count'] > 0 else 0
        features['has_images'] = 1 if features['images_count'] > 0 else 0
        
        # Composite features
        features['completeness_score'] = (
            (1 if features['has_furniture'] else 0) +
            (1 if features['has_amenities'] else 0) +
            (1 if features['has_images'] else 0)
        ) / 3.0
        
        # ==================== GEOGRAPHIC FEATURES ====================
        
        # 🔥 NEW: Geographic features
        features['longitude'] = float(rental.get('longitude', 0))
        features['latitude'] = float(rental.get('latitude', 0))
        
        # Flag if coordinates are valid
        features['has_valid_coordinates'] = 1 if (
            features['longitude'] != 0 and features['latitude'] != 0
        ) else 0
        
        # Geographic region (simplified - could be from coordinates)
        # For now, use location text as proxy
        features['is_central_area'] = 1 if any(
            keyword in features['location_text'].lower() 
            for keyword in ['quận 1', 'hcm', 'hanoi', 'district 1']
        ) else 0
        
        return features
    
    def _get_default_user_features(self):
        """Default features for new users"""
        return {
            # Interaction features
            'total_interactions': 0,
            'view_count': 0,
            'click_count': 0,
            'favorite_count': 0,
            'contact_count': 0,
            'avg_interaction_score': 0,
            'total_interaction_score': 0,
            'engagement_rate': 0,
            
            # Price features
            'avg_price_viewed': 0,
            'min_price_viewed': 0,
            'max_price_viewed': 0,
            'price_std': 0,
            'price_range': 0,
            
            # Property type features
            'preferred_property_type': 'unknown',
            'property_type_diversity': 0,
            
            # Location features
            'preferred_location': 'unknown',
            'location_diversity': 0,
            
            # 🔥 NEW: Geographic features
            'user_centroid_longitude': 0,
            'user_centroid_latitude': 0,
            'location_spread_lon': 0,
            'location_spread_lat': 0,
            'geographic_diversity': 0,
            'max_search_radius_km': 0,
            
            # Area features
            'avg_area_viewed': 0,
            'min_area_viewed': 0,
            'max_area_viewed': 0,
            'area_std': 0,
            
            # Time-based features
            'days_since_first_interaction': 0,
            'days_since_last_interaction': 0,
            'avg_interactions_per_day': 0,
            
            # Recent activity
            'recent_interactions_7d': 0,
            'recent_favorites_7d': 0
        }


if __name__ == '__main__':
    # Test feature extraction
    print("🔧 FeatureEngineer Test\n")
    
    fe = FeatureEngineer()
    
    # Test user features
    print("📊 Testing User Features:")
    default_user = fe._get_default_user_features()
    print(f"   Total features: {len(default_user)}")
    print(f"   Sample features: {list(default_user.keys())[:5]}")
    
    # Test item features
    print("\n🏠 Testing Item Features:")
    sample_rental = {
        'price': 5000000,
        'area_total': 30,
        'area_bedrooms': 1,
        'amenities_count': 5,
        'furniture_count': 1,
        'images_count': 8,
        'propertyType': 'Nhà riêng',
        'location_short': 'Quận Bình Thủy',
        'longitude': 105.7845,
        'latitude': 10.0123
    }
    item_features = fe.extract_item_features(sample_rental)
    print(f"   Total features: {len(item_features)}")
    print(f"   Sample features:")
    for key in ['price', 'longitude', 'latitude', 'has_valid_coordinates', 'price_per_sqm']:
        print(f"      {key}: {item_features[key]}")
    
    print("\n✅ FeatureEngineer ready for training!")