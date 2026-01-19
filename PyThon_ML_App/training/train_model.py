import os
import sys
import pandas as pd
import numpy as np
import joblib
from datetime import datetime
from sklearn.metrics.pairwise import cosine_similarity
from sklearn.preprocessing import StandardScaler, LabelEncoder
from scipy.sparse import csr_matrix
from collections import defaultdict
from math import radians, sin, cos, sqrt, atan2

sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

class RecommendationModel:
    _instance = None

    @classmethod
    def get_instance(cls):
        """Singleton pattern - load model 1 lần"""
        if cls._instance is None:
            cls._instance = cls.load('./models/recommendation_model.pkl')
        return cls._instance

    def __init__(self):
        self.user_item_matrix = None
        self.user_similarity = None
        self.item_similarity = None
        self.user_features = {}
        self.item_features = {}
        self.user_encoder = LabelEncoder()
        self.item_encoder = LabelEncoder()
        self.scaler = StandardScaler()

        # Store rental coordinates
        self.rental_coordinates = {}  # {rental_id: (longitude, latitude)}
        self.user_locations = {}      # {user_id: (longitude, latitude)}

        # Popularity scores
        self.popularity_scores = {}

        # Store interactions for preference calculation
        self.interactions_df = None

        print("✅ RecommendationModel initialized")
    
    def prepare_data(self, interactions_df, rentals_df):
        """Chuẩn bị dữ liệu cho training"""
        print("\n📊 Preparing data...")
        
        # Store interactions for later use
        self.interactions_df = interactions_df.copy()
        
        # Filter valid interactions
        valid_interactions = interactions_df[
            (interactions_df['userId'].notna()) & 
            (interactions_df['rentalId'].notna())
        ].copy()
        
        print(f"   Total interactions: {len(valid_interactions)}")
        print(f"   Unique users: {valid_interactions['userId'].nunique()}")
        print(f"   Unique rentals: {valid_interactions['rentalId'].nunique()}")
        
        # Store rental coordinates
        print("\n   📍 Loading rental coordinates...")
        for idx, row in rentals_df.iterrows():
            rental_id = str(row['_id'])
            lon = float(row.get('longitude', 0))
            lat = float(row.get('latitude', 0))
            self.rental_coordinates[rental_id] = (lon, lat)
        
        print(f"      Stored {len(self.rental_coordinates)} rental coordinates")
        
        # Calculate user location centroids from interactions
        print("   👥 Calculating user location centroids...")
        self._calculate_user_locations(valid_interactions)
        
        # Encode users and items
        valid_interactions['user_idx'] = self.user_encoder.fit_transform(valid_interactions['userId'])
        valid_interactions['item_idx'] = self.item_encoder.fit_transform(valid_interactions['rentalId'])
        
        return valid_interactions, rentals_df
    
    def _calculate_user_locations(self, interactions_df):
        """Tính toán vị trí trung bình của user từ interactions"""
        try:
            for user_id in interactions_df['userId'].unique():
                user_interactions = interactions_df[interactions_df['userId'] == user_id]
                
                # Lấy tất cả tọa độ mà user đã tương tác
                valid_coords = []
                for _, row in user_interactions.iterrows():
                    rental_id = str(row['rentalId'])
                    if rental_id in self.rental_coordinates:
                        coords = self.rental_coordinates[rental_id]
                        if coords[0] != 0 and coords[1] != 0:
                            valid_coords.append(coords)
                
                # Tính trung bình
                if valid_coords:
                    avg_lon = np.mean([c[0] for c in valid_coords])
                    avg_lat = np.mean([c[1] for c in valid_coords])
                    self.user_locations[user_id] = (avg_lon, avg_lat)
            
            print(f"      Calculated locations for {len(self.user_locations)} users")
        
        except Exception as e:
            print(f"      ⚠️ Error calculating user locations: {e}")
    
    def build_user_item_matrix(self, interactions_df):
        """Xây dựng User-Item Interaction Matrix"""
        print("\n🔨 Building User-Item Matrix...")
        
        # Aggregate interactions by user-item pairs
        interaction_scores = interactions_df.groupby(['user_idx', 'item_idx'])['interactionScore'].sum().reset_index()
        
        n_users = len(self.user_encoder.classes_)
        n_items = len(self.item_encoder.classes_)
        
        print(f"   Matrix size: {n_users} users × {n_items} items")
        
        # Create sparse matrix
        self.user_item_matrix = csr_matrix(
            (interaction_scores['interactionScore'], 
             (interaction_scores['user_idx'], interaction_scores['item_idx'])),
            shape=(n_users, n_items)
        )
        
        print(f"   Sparsity: {100 * (1 - self.user_item_matrix.nnz / (n_users * n_items)):.2f}%")
    
    def compute_user_similarity(self):
        """Tính User-User Similarity (Collaborative Filtering)"""
        print("\n🧮 Computing User-User Similarity...")
        
        # Normalize user vectors
        user_norms = np.sqrt(np.array(self.user_item_matrix.power(2).sum(axis=1)).flatten())
        user_norms[user_norms == 0] = 1
        
        normalized_matrix = self.user_item_matrix.multiply(1 / user_norms[:, np.newaxis])
        
        # Compute cosine similarity
        self.user_similarity = cosine_similarity(normalized_matrix, dense_output=False)
        
        print(f"   Computed similarity for {self.user_similarity.shape[0]} users")
    
    def compute_item_similarity(self):
        """Tính Item-Item Similarity (Content-Based)"""
        print("\n🧮 Computing Item-Item Similarity...")
        
        # Transpose to get item vectors
        item_matrix = self.user_item_matrix.T
        
        # Normalize
        item_norms = np.sqrt(np.array(item_matrix.power(2).sum(axis=1)).flatten())
        item_norms[item_norms == 0] = 1
        
        normalized_matrix = item_matrix.multiply(1 / item_norms[:, np.newaxis])
        
        # Compute similarity
        self.item_similarity = cosine_similarity(normalized_matrix, dense_output=False)
        
        print(f"   Computed similarity for {self.item_similarity.shape[0]} items")
    
    def compute_popularity_scores(self, interactions_df):
        """Tính popularity score cho mỗi item"""
        print("\n⭐ Computing Popularity Scores...")
        
        rental_scores = interactions_df.groupby('rentalId').agg({
            'interactionScore': 'sum',
            'userId': 'nunique'
        }).reset_index()
        
        rental_scores.columns = ['rentalId', 'total_score', 'unique_users']
        
        # Weighted popularity
        rental_scores['popularity'] = rental_scores['total_score'] * np.log1p(rental_scores['unique_users'])
        
        # Normalize to 0-100
        max_pop = rental_scores['popularity'].max()
        if max_pop > 0:
            rental_scores['popularity'] = (rental_scores['popularity'] / max_pop) * 100
        
        self.popularity_scores = dict(zip(rental_scores['rentalId'], rental_scores['popularity']))
        
        print(f"   Computed popularity for {len(self.popularity_scores)} items")
        print(f"   Top item popularity: {rental_scores['popularity'].max():.2f}")

    def get_user_preferences(self, user_id):
        """Lấy preferences của user từ interactions"""
        try:
            if self.interactions_df is None:
                return None
                
            user_interactions = self.interactions_df[self.interactions_df['userId'] == user_id]
            
            if len(user_interactions) == 0:
                return None
            
            prefs = {
                'property_type_distribution': user_interactions.get('propertyType', pd.Series([])).value_counts().to_dict(),
                'price_range': {
                    'min': float(user_interactions['price'].min()) if 'price' in user_interactions else 0,
                    'max': float(user_interactions['price'].max()) if 'price' in user_interactions else 0,
                    'avg': float(user_interactions['price'].mean()) if 'price' in user_interactions else 0,
                    'median': float(user_interactions['price'].median()) if 'price' in user_interactions else 0,
                },
                'area_range': {
                    'min': float(user_interactions['area'].min()) if 'area' in user_interactions else 0,
                    'max': float(user_interactions['area'].max()) if 'area' in user_interactions else 0,
                    'avg': float(user_interactions['area'].mean()) if 'area' in user_interactions else 0,
                },
                'top_locations': user_interactions.get('location_text', pd.Series([])).value_counts().head(3).to_dict(),
                'interaction_types': user_interactions['interactionType'].value_counts().to_dict() if 'interactionType' in user_interactions else {},
                'avg_scroll_depth': float(user_interactions.get('scrollDepth', pd.Series([0])).mean()),
                'avg_duration': float(user_interactions.get('duration', pd.Series([0])).mean()),
                'total_interactions': len(user_interactions),
            }
            
            return prefs
        except Exception as e:
            print(f"Error getting user preferences: {e}")
            return None
    
    @staticmethod
    def _haversine_distance(lon1, lat1, lon2, lat2):
        """Tính khoảng cách giữa 2 điểm bằng công thức Haversine (km)"""
        R = 6371  # Earth radius in km
        
        lat1, lon1, lat2, lon2 = map(radians, [lat1, lon1, lat2, lon2])
        dlat = lat2 - lat1
        dlon = lon2 - lon1
        
        a = sin(dlat/2)**2 + cos(lat1) * cos(lat2) * sin(dlon/2)**2
        c = 2 * atan2(sqrt(a), sqrt(1-a))
        
        return R * c
    
    def train(self, interactions_df, rentals_df):
        """Train toàn bộ model"""
        print("\n" + "="*70)
        print("🚀 STARTING MODEL TRAINING WITH GEOGRAPHIC FEATURES")
        print("="*70)
        
        # 1. Data validation - 🔥 CRITICAL
        print("\n📊 DATA VALIDATION:")
        print(f"   Total interactions: {len(interactions_df)}")
        print(f"   Unique users: {interactions_df['userId'].nunique()}")
        print(f"   Unique rentals: {interactions_df['rentalId'].nunique()}")
        
        min_users = 5
        min_interactions = 20
        min_rentals = 10
        
        if interactions_df['userId'].nunique() < min_users:
            print(f"\n⚠️ WARNING: Too few users ({interactions_df['userId'].nunique()} < {min_users})")
            print("   Model may not provide good personalization")
            response = input("Continue anyway? (y/n): ")
            if response.lower() != 'y':
                print("Training cancelled.")
                return
        
        if len(interactions_df) < min_interactions:
            print(f"\n⚠️ WARNING: Too few interactions ({len(interactions_df)} < {min_interactions})")
            print("   Consider collecting more data first")
        
        # 2. Prepare data
        interactions_df, rentals_df = self.prepare_data(interactions_df, rentals_df)
        
        # 3. Build matrices
        self.build_user_item_matrix(interactions_df)
        
        # 4. 🔥 IMPROVED: Compute similarities dengan better normalization
        print("\n🧮 Computing Similarities...")
        self.compute_user_similarity()
        self.compute_item_similarity()
        
        # 5. Compute popularity
        self.compute_popularity_scores(interactions_df)
        
        # 6. 🔥 NEW: Extract item features for personalization
        print("\n📋 Extracting item features...")
        self.item_features = {}
        
        # 🔥 FIX: Use iterrows() instead of itertuples()
        for idx, row in rentals_df.iterrows():
            try:
                rental_id = str(row['_id'])
                
                self.item_features[rental_id] = {
                    'price': float(row['price']) if pd.notna(row['price']) else 0,
                    'propertyType': str(row['propertyType']) if pd.notna(row['propertyType']) else 'unknown',
                    'location_text': str(row.get('location_short', 'unknown')) if 'location_short' in row and pd.notna(row.get('location_short')) else 'unknown',
                    'area': float(row.get('area_total', 0)) if 'area_total' in row and pd.notna(row.get('area_total')) else 0,
                    'amenities': row.get('amenities', []) if 'amenities' in row and isinstance(row.get('amenities'), list) else [],
                }
            except Exception as e:
                print(f"      ⚠️ Error extracting features for rental {idx}: {e}")
                continue
        
        print(f"   ✅ Extracted features for {len(self.item_features)} items")
        
        print("\n" + "="*70)
        print("✅ TRAINING COMPLETED")
        print("="*70 + "\n")
        
        # Summary
        print("📊 MODEL SUMMARY:")
        print(f"   Users: {len(self.user_encoder.classes_)}")
        print(f"   Items: {len(self.item_encoder.classes_)}")
        print(f"   User-Item interactions: {self.user_item_matrix.nnz}")
        print(f"   Sparsity: {100 * (1 - self.user_item_matrix.nnz / (len(self.user_encoder.classes_) * len(self.item_encoder.classes_))):.2f}%")
        print(f"   Rental coordinates: {len(self.rental_coordinates)}")
        print(f"   User locations: {len(self.user_locations)}")
        print(f"   Item features: {len(self.item_features)}\n")
    
    def recommend_for_user(self, user_id, n_recommendations=10, exclude_items=None, 
                          use_location=True, radius_km=20, context=None):
        """
        🎯 Improved personalized recommendation - 🔥 BETTER ALGORITHM
        """
        context = context or {}
        user_location = self.user_locations.get(user_id)
        
        # Check if user exists
        if user_id not in self.user_encoder.classes_:
            print(f"⚠️ New user {user_id}, using popularity-based recommendations")
            return self.get_popular_items(n_recommendations, exclude_items)
        
        user_idx = self.user_encoder.transform([user_id])[0]
        user_prefs = self.get_user_preferences(user_id)
        
        # Get similar users - 🔥 IMPROVED
        user_similarities = self.user_similarity[user_idx].toarray().flatten()
        similar_users_idx = np.argsort(user_similarities)[::-1][1:min(101, len(user_similarities))]  # Top 100 similar users
        
        # Filter by minimum similarity
        min_similarity_threshold = 0.1
        valid_similar_users = [idx for idx in similar_users_idx if user_similarities[idx] > min_similarity_threshold]
        
        print(f"   Found {len(valid_similar_users)} similar users (threshold: {min_similarity_threshold})")
        
        # Get items from similar users
        candidate_scores = defaultdict(float)
        candidate_metadata = defaultdict(lambda: {'reasons': [], 'scores': {}})
        
        for similar_user_idx in valid_similar_users[:50]:  # Top 50 to avoid too much data
            similarity_score = user_similarities[similar_user_idx]
            user_items = self.user_item_matrix[similar_user_idx].toarray().flatten()
            
            for item_idx, interaction_score in enumerate(user_items):
                if interaction_score > 0:
                    # Skip if user already interacted
                    if self.user_item_matrix[user_idx, item_idx] > 0:
                        continue
                    
                    # Calculate weighted score
                    weighted_score = similarity_score * interaction_score
                    candidate_scores[item_idx] += weighted_score
                    candidate_metadata[item_idx]['reasons'].append(f"Similar user interaction ({interaction_score:.1f})")
                    candidate_metadata[item_idx]['scores']['collaborative'] = weighted_score
        
        # 🔥 ADD: Content-based filtering
        user_item_vector = self.user_item_matrix[user_idx].toarray().flatten()
        
        # Find items similar to what user likes
        if user_item_vector.sum() > 0:
            item_similarities = cosine_similarity([user_item_vector], self.item_similarity)[0]
            
            for item_idx, sim_score in enumerate(item_similarities):
                if sim_score > 0.2 and self.user_item_matrix[user_idx, item_idx] == 0:
                    weighted_sim = sim_score * 0.5  # Weight it less than collaborative
                    candidate_scores[item_idx] += weighted_sim
                    candidate_metadata[item_idx]['reasons'].append(f"Similar to liked items ({sim_score:.2f})")
        
        # Sort by score
        sorted_items = sorted(candidate_scores.items(), key=lambda x: x[1], reverse=True)
        
        recommendations = []
        for item_idx, score in sorted_items:
            rental_id = self.item_encoder.inverse_transform([item_idx])[0]
            
            if exclude_items and rental_id in exclude_items:
                continue
            
            if context.get('impressions') and rental_id in context.get('impressions'):
                continue
            
            # LOCATION BONUS - 🔥 IMPROVED
            location_bonus = 1.0
            distance = None
            
            if use_location and user_location and rental_id in self.rental_coordinates:
                rental_coords = self.rental_coordinates[rental_id]
                
                if rental_coords[0] != 0 and rental_coords[1] != 0:
                    distance = self._haversine_distance(
                        user_location[0], user_location[1],
                        rental_coords[0], rental_coords[1]
                    )
                    
                    # Better distance scoring
                    if distance <= radius_km:
                        # Closer = exponential boost
                        location_bonus = 1.0 + (1.0 - (distance / radius_km)) ** 2
                    else:
                        location_bonus = 0.3  # Heavier penalty for far items
            
            # PREFERENCE MATCHING - 🔥 IMPROVED
            preference_bonus = 1.0
            
            if user_prefs:
                # Price matching
                if 'price_range' in user_prefs:
                    price_min = user_prefs['price_range'].get('min', 0)
                    price_max = user_prefs['price_range'].get('max', float('inf'))
                    avg_price = user_prefs['price_range'].get('avg', 0)
                    
                    if str(rental_id) in self.item_features:
                        rental_price = self.item_features[str(rental_id)].get('price', 0)
                        
                        if price_min <= rental_price <= price_max:
                            # Perfect match gets bonus
                            price_diff = abs(rental_price - avg_price)
                            max_diff = max(avg_price - price_min, price_max - avg_price)
                            price_match = 1.0 - (price_diff / max_diff) if max_diff > 0 else 1.0
                            preference_bonus *= (0.9 + 0.2 * price_match)
            
            # TIME BONUS - 🔥 NEW
            time_bonus = 1.0
            time_of_day = context.get('time_of_day', 'morning')
            
            if user_prefs and user_prefs.get('total_interactions', 0) > 10:
                # Boost if user is typically active at this time
                time_bonus = 1.05
            
            # Calculate final score
            final_score = score * location_bonus * preference_bonus * time_bonus
            
            recommendations.append({
                'rentalId': rental_id,
                'score': float(score),
                'locationBonus': float(location_bonus),
                'preferenceBonus': float(preference_bonus),
                'timeBonus': float(time_bonus),
                'finalScore': float(final_score),
                'method': 'collaborative_personalized',
                'coordinates': self.rental_coordinates.get(rental_id, (0, 0)),
                'distance_km': distance,
                'confidence': min(1.0, float(score / 10.0)) if score > 0 else 0.5,
            })
            
            if len(recommendations) >= n_recommendations * 2:
                break
        
        # Sort by final score
        recommendations.sort(key=lambda x: x['finalScore'], reverse=True)
        
        return recommendations[:n_recommendations]
    
    def recommend_similar_items(self, item_id, n_recommendations=10, use_location=True, context=None):
        """
        🏘️ Tìm các bài đăng tương tự + Explainable AI
        """
        context = context or {}
        
        if item_id not in self.item_encoder.classes_:
            print(f"⚠️ Item {item_id} not found")
            return []
        
        item_idx = self.item_encoder.transform([item_id])[0]
        item_similarities = self.item_similarity[item_idx].toarray().flatten()
        
        # Get reference rental's location
        ref_location = self.rental_coordinates.get(item_id, (0, 0))
        
        # Get top K similar items
        similar_items_idx = np.argsort(item_similarities)[::-1][1:n_recommendations+10]
        
        recommendations = []
        for idx in similar_items_idx:
            rental_id = self.item_encoder.inverse_transform([idx])[0]
            
            # Skip if already shown
            if context.get('impressions') and rental_id in context.get('impressions'):
                continue
            
            base_score = float(item_similarities[idx])

            rental_coords = self.rental_coordinates.get(rental_id, (0, 0))

            if not isinstance(rental_coords, (tuple, list)):
                rental_coords = (0, 0)
            elif len(rental_coords) < 2:
                rental_coords = (0, 0)
            else:
                rental_coords = (float(rental_coords[0]), float(rental_coords[1]))
            
            # LOCATION PROXIMITY BONUS
            location_bonus = 1.0
            distance = None
        
            if use_location and ref_location[0] != 0 and ref_location[1] != 0:
                if rental_coords[0] != 0 and rental_coords[1] != 0:
                    distance = self._haversine_distance(
                        ref_location[0], ref_location[1],
                        rental_coords[0], rental_coords[1]
                    )
                    
                    # Gần nhất có bonus cao hơn
                    if distance <= 5:  # 5km
                        location_bonus = 1.0 + (1.0 - distance / 5.0) * 0.3
                    else:
                        location_bonus = max(0.7, 1.0 - distance / 50.0)
        
            final_score = base_score * location_bonus
        
            recommendations.append({
                'rentalId': rental_id,
                'score': base_score,
                'locationBonus': location_bonus,
                'finalScore': final_score,
                'method': 'content_based_similar',
                'coordinates': rental_coords,  # 🔥 Always valid tuple
                'distance_km': distance,
                'confidence': min(1.0, base_score * location_bonus),
            })
    
        # Sort by final score
        recommendations.sort(key=lambda x: x['finalScore'], reverse=True)
        
        return recommendations[:n_recommendations]
    
    def get_popular_items(self, n_recommendations=10, exclude_items=None, context=None):
        """
        ⭐ Lấy các bài đăng phổ biến + explanation
        """
        context = context or {}
        
        sorted_items = sorted(
            self.popularity_scores.items(), 
            key=lambda x: x[1], 
            reverse=True
        )
        
        recommendations = []
        for rental_id, score in sorted_items:
            if exclude_items and rental_id in exclude_items:
                continue
            
            if context.get('impressions') and rental_id in context.get('impressions'):
                continue
            
            recommendations.append({
                'rentalId': rental_id,
                'score': float(score),
                'method': 'popularity',
                'coordinates': self.rental_coordinates.get(rental_id, (0, 0)),
                'explanation': {
                    'popularity': f'Được {int(score)} người quan tâm'
                },
                'confidence': min(1.0, score / 100),
            })
            
            if len(recommendations) >= n_recommendations:
                break
        
        return recommendations
    
    def save(self, filepath='./models/recommendation_model.pkl'):
        """Lưu model"""
        print(f"\n💾 Saving model to {filepath}...")
        
        os.makedirs(os.path.dirname(filepath), exist_ok=True)
        
        model_data = {
            'user_item_matrix': self.user_item_matrix,
            'user_similarity': self.user_similarity,
            'item_similarity': self.item_similarity,
            'user_encoder': self.user_encoder,
            'item_encoder': self.item_encoder,
            'popularity_scores': self.popularity_scores,
            'rental_coordinates': self.rental_coordinates,
            'user_locations': self.user_locations,
            'trained_at': datetime.now().isoformat()
        }
        
        joblib.dump(model_data, filepath)
        
        print(f"✅ Model saved successfully")
        print(f"   File size: {os.path.getsize(filepath) / (1024*1024):.2f} MB")
        print(f"   Rental coordinates stored: {len(self.rental_coordinates)}")
        print(f"   User locations calculated: {len(self.user_locations)}")
    
    @classmethod
    def load(cls, filepath='./models/recommendation_model.pkl'):
        """Load model từ file"""
        print(f"\n📂 Loading model from {filepath}...")
        
        if not os.path.exists(filepath):
            raise FileNotFoundError(f"Model file not found: {filepath}")
        
        model_data = joblib.load(filepath)
        
        model = cls()
        model.user_item_matrix = model_data['user_item_matrix']
        model.user_similarity = model_data['user_similarity']
        model.item_similarity = model_data['item_similarity']
        model.user_encoder = model_data['user_encoder']
        model.item_encoder = model_data['item_encoder']
        model.popularity_scores = model_data['popularity_scores']
        model.rental_coordinates = model_data.get('rental_coordinates', {})
        model.user_locations = model_data.get('user_locations', {})
        
        print(f"✅ Model loaded successfully")
        print(f"   Trained at: {model_data.get('trained_at', 'unknown')}")
        print(f"   Rental coordinates loaded: {len(model.rental_coordinates)}")
        print(f"   User locations loaded: {len(model.user_locations)}")
        
        return model


def main():
    """Main training pipeline"""
    print("\n" + "="*70)
    print("🤖 RENTAL RECOMMENDATION MODEL TRAINING WITH GEO FEATURES")
    print("="*70 + "\n")
    
    # ========================================
    # BƯỚC 1: LOAD DATA
    # ========================================
    print("📂 Loading datasets...")
    
    if not os.path.exists('./data/interactions.csv'):
        print("❌ interactions.csv not found!")
        print("   Run: python data/export_dataset.py first")
        return
    
    if not os.path.exists('./data/rentals.csv'):
        print("❌ rentals.csv not found!")
        print("   Run: python data/export_dataset.py first")
        return
    
    interactions_df = pd.read_csv('./data/interactions.csv')
    rentals_df = pd.read_csv('./data/rentals.csv')
    
    print(f"✅ Loaded {len(interactions_df)} interactions")
    print(f"✅ Loaded {len(rentals_df)} rentals")
    
    # Check coordinates
    valid_interaction_coords = len(interactions_df[
        (interactions_df['longitude'] != 0) & (interactions_df['latitude'] != 0)
    ])
    print(f"✅ Interactions with coordinates: {valid_interaction_coords}/{len(interactions_df)}")
    
    valid_rental_coords = len(rentals_df[
        (rentals_df['longitude'] != 0) & (rentals_df['latitude'] != 0)
    ])
    print(f"✅ Rentals with coordinates: {valid_rental_coords}/{len(rentals_df)}\n")
    
    # Check if enough data
    if len(interactions_df) < 100:
        print("\n⚠️ WARNING: Too few interactions for meaningful training!")
        response = input("Continue anyway? (y/n): ")
        if response.lower() != 'y':
            print("Training cancelled.")
            return
    
    # ========================================
    # BƯỚC 2: TRAIN MODEL
    # ========================================
    model = RecommendationModel()
    model.train(interactions_df, rentals_df)
    
    # ========================================
    # BƯỚC 3: TEST RECOMMENDATIONS
    # ========================================
    print("\n📊 Testing recommendations...\n")
    
    if len(interactions_df) > 0:
        test_user = interactions_df['userId'].iloc[0]
        recommendations = model.recommend_for_user(test_user, n_recommendations=5)
        
        print(f"   Test recommendations for user '{test_user}':")
        for i, rec in enumerate(recommendations, 1):
            coords = rec['coordinates']
            distance = rec.get('distance_km', 'N/A')
            print(f"   {i}. {rec['rentalId']}")
            print(f"      Score: {rec['score']:.2f}, Location bonus: {rec['locationBonus']:.2f}")
            print(f"      Final score: {rec['finalScore']:.2f}, Distance: {distance}km")
            print(f"      Coordinates: ({coords[0]:.4f}, {coords[1]:.4f})")
            if 'explanation' in rec and rec['explanation']:
                print(f"      Explanation: {rec['explanation']}")
    
    # Test similar items
    if len(rentals_df) > 0:
        test_rental = str(rentals_df['_id'].iloc[0])
        similar = model.recommend_similar_items(test_rental, n_recommendations=3)
        
        print(f"\n   Similar items to {test_rental}:")
        for i, rec in enumerate(similar, 1):
            coords = rec['coordinates']
            distance = rec.get('distance_km', 'N/A')
            print(f"   {i}. {rec['rentalId']} (distance: {distance}km)")
            print(f"      Score: {rec['score']:.2f}, Final: {rec['finalScore']:.2f}")
            print(f"      Coordinates: ({coords[0]:.4f}, {coords[1]:.4f})")
            if 'explanation' in rec and rec['explanation']:
                print(f"      Explanation: {rec['explanation']}")
    
    # ========================================
    # BƯỚC 4: SAVE MODEL
    # ========================================
    model.save('./models/recommendation_model.pkl')
    
    # ========================================
    # ✨ BƯỚC 5: TỰ ĐỘNG TẠO VISUALIZATION
    # ========================================
    print("\n" + "="*70)
    print("🎨 GENERATING MODEL VISUALIZATIONS")
    print("="*70 + "\n")
    
    try:
        # Import ModelVisualizer từ cùng thư mục
        import sys
        current_dir = os.path.dirname(os.path.abspath(__file__))
        sys.path.insert(0, current_dir)
        
        from model_visualizer import ModelVisualizer
        
        # Tạo thư mục reports
        reports_dir = './reports'
        os.makedirs(reports_dir, exist_ok=True)
        print(f"📁 Reports directory: {os.path.abspath(reports_dir)}\n")
        
        # Khởi tạo visualizer
        visualizer = ModelVisualizer(model_path='./models/recommendation_model.pkl')
        
        # Tạo từng biểu đồ
        print("📊 Creating visualizations...")
        print("-" * 70)
        
        stats = visualizer.plot_matrix_heatmap()
        visualizer.plot_interaction_distribution()
        visualizer.plot_user_similarity_heatmap()
        visualizer.plot_popularity_chart()
        visualizer.plot_geographic_distribution()
        visualizer.plot_interactions_per_user()
        visualizer.plot_interactions_per_item()
        
        print("-" * 70)
        print("\n" + "="*70)
        print("✅ VISUALIZATION COMPLETED SUCCESSFULLY")
        print("="*70 + "\n")
        
        # Liệt kê file đã tạo
        print("📊 Generated Visualization Reports:")
        print(f"   📁 Location: {os.path.abspath(reports_dir)}/")
        print("\n   Files created:")
        
        report_files = [
            ('1_user_item_matrix.png', 'User-Item Interaction Matrix'),
            ('2_interaction_distribution.png', 'Interaction Score Distribution'),
            ('3_user_similarity.png', 'User-User Similarity Heatmap'),
            ('4_popularity_ranking.png', 'Top 10 Most Popular Rentals'),
            ('5_geographic_distribution.png', 'Geographic Distribution Map'),
            ('6_interactions_per_user.png', 'Interactions per User'),
            ('7_interactions_per_item.png', 'Interactions per Rental'),
        ]
        
        for filename, description in report_files:
            filepath = os.path.join(reports_dir, filename)
            if os.path.exists(filepath):
                size_kb = os.path.getsize(filepath) / 1024
                print(f"   ✅ {filename:<35} | {size_kb:>6.1f} KB | {description}")
            else:
                print(f"   ⚠️  {filename:<35} | MISSING")
        
        print()
        
        # In thống kê chi tiết
        print("=" * 70)
        print("📈 MODEL STATISTICS SUMMARY")
        print("=" * 70)
        print(f"   👥 Total Users:           {stats['n_users']:>6,}")
        print(f"   🏠 Total Rentals:         {stats['n_items']:>6,}")
        print(f"   📊 Matrix Size:           {stats['n_users']:>6,} × {stats['n_items']:<6,} = {stats['total_cells']:>10,} cells")
        print(f"   💾 Non-zero Cells:        {stats['nnz']:>10,}")
        print(f"   📉 Matrix Sparsity:       {stats['sparsity']:>9.2f}%")
        print(f"   📈 Matrix Density:        {stats['density']:>9.2f}%")
        print("=" * 70)
        print()
        
        # Hướng dẫn xem báo cáo
        print("💡 HOW TO VIEW REPORTS:")
        print("   Option 1 (Docker): docker cp python-ml:/app/reports ./local_reports")
        print("   Option 2 (Local):  Open files in ./reports/ folder")
        print("   Option 3 (VSCode): Click on files in Explorer panel")
        print()
        
    except ImportError as e:
        print(f"\n⚠️ WARNING: Cannot import ModelVisualizer")
        print(f"   Error: {e}")
        print(f"   Make sure model_visualizer.py is in: {current_dir}/")
        print(f"   Training completed successfully, but visualizations skipped.")
        
    except FileNotFoundError as e:
        print(f"\n⚠️ WARNING: Model file not found")
        print(f"   Error: {e}")
        print(f"   Make sure model is saved at: ./models/recommendation_model.pkl")
        
    except Exception as e:
        print(f"\n⚠️ WARNING: Failed to generate visualizations")
        print(f"   Error: {e}")
        print(f"   Training completed successfully, but visualizations skipped.")
        print(f"\n   🐛 Debug info:")
        import traceback
        traceback.print_exc()
        
    # ========================================
    # BƯỚC 6: KẾT THÚC
    # ========================================
    print("\n" + "="*70)
    print("✅ TRAINING PIPELINE COMPLETED")
    print("="*70 + "\n")
    
    print("🚀 NEXT STEPS:")
    print("   1. ✅ Model trained and saved")
    print("   2. ✅ Visualizations generated")
    print("   3. 📊 View reports in ./reports/ folder")
    print("   4. 🚀 Start API: python app/main.py")
    print("   5. 🧪 Test API: curl http://localhost:8001/health")
    print("   6. 🎯 Get recommendations: POST http://localhost:8001/recommend/personalized")
    print()
    print("=" * 70)
    print()


if __name__ == '__main__':
    main()