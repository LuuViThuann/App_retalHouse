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
        
        # 1. Prepare data
        interactions_df, rentals_df = self.prepare_data(interactions_df, rentals_df)
        
        # 2. Build matrices
        self.build_user_item_matrix(interactions_df)
        
        # 3. Compute similarities
        self.compute_user_similarity()
        self.compute_item_similarity()
        
        # 4. Compute popularity
        self.compute_popularity_scores(interactions_df)
        
        print("\n" + "="*70)
        print("✅ TRAINING COMPLETED")
        print("="*70 + "\n")
    
    def recommend_for_user(self, user_id, n_recommendations=10, exclude_items=None, 
                          use_location=True, radius_km=20, context=None):
        """
        🎯 Gợi ý cá nhân hóa với Explainable AI
        
        context = {
            'map_center': (lon, lat),
            'zoom_level': 15,
            'search_radius': 10,
            'time_of_day': 'morning',
            'weekday': 'Monday',
            'device_type': 'mobile',
            'impressions': [],
            'scroll_depth': 0.8,
        }
        """
        context = context or {}
        user_location = self.user_locations.get(user_id)
        
        # Check if user exists
        if user_id not in self.user_encoder.classes_:
            print(f"⚠️ New user {user_id}, using popularity-based recommendations")
            return self.get_popular_items(n_recommendations, exclude_items)
        
        user_idx = self.user_encoder.transform([user_id])[0]
        user_prefs = self.get_user_preferences(user_id)
        
        # Get similar users
        user_similarities = self.user_similarity[user_idx].toarray().flatten()
        similar_users_idx = np.argsort(user_similarities)[::-1][1:51]
        
        # Get items from similar users
        candidate_scores = defaultdict(float)
        candidate_reasons = defaultdict(list)
        
        for similar_user_idx in similar_users_idx:
            similarity_score = user_similarities[similar_user_idx]
            
            if similarity_score <= 0:
                continue
            
            user_items = self.user_item_matrix[similar_user_idx].toarray().flatten()
            
            for item_idx, interaction_score in enumerate(user_items):
                if interaction_score > 0:
                    if self.user_item_matrix[user_idx, item_idx] > 0:
                        continue
                    
                    candidate_scores[item_idx] += similarity_score * interaction_score
                    candidate_reasons[item_idx].append('collaborative_filtering')
        
        # Sort by score
        sorted_items = sorted(candidate_scores.items(), key=lambda x: x[1], reverse=True)
        
        recommendations = []
        for item_idx, score in sorted_items:
            rental_id = self.item_encoder.inverse_transform([item_idx])[0]
            
            if exclude_items and rental_id in exclude_items:
                continue
            
            # Skip if already shown (impression)
            if context.get('impressions') and rental_id in context.get('impressions'):
                continue
            
            # LOCATION BONUS
            location_bonus = 1.0
            distance = None
            location_reason = None
            
            if use_location and user_location and rental_id in self.rental_coordinates:
                rental_coords = self.rental_coordinates[rental_id]
                
                if rental_coords[0] != 0 and rental_coords[1] != 0:
                    distance = self._haversine_distance(
                        user_location[0], user_location[1],
                        rental_coords[0], rental_coords[1]
                    )
                    
                    # Gần hơn → điểm cao hơn
                    if distance <= radius_km:
                        location_bonus = 1.0 + (1.0 - distance / radius_km) * 0.5
                        location_reason = f'Gần vị trí bạn hay tìm ({distance:.1f}km)'
                    else:
                        location_bonus = 0.5
            
            # PREFERENCE MATCHING
            preference_bonus = 1.0
            preference_reasons = []
            
            if user_prefs:
                # Price preference matching
                if 'price_range' in user_prefs:
                    price_min = user_prefs['price_range']['min']
                    price_max = user_prefs['price_range']['max']
                    
                    # Lấy rental price từ item_features nếu có
                    if hasattr(self, 'item_features') and rental_id in self.item_features:
                        rental_price = self.item_features[rental_id].get('price', 0)
                        
                        if price_min <= rental_price <= price_max:
                            preference_bonus *= 1.2
                            preference_reasons.append('Trong tầm giá bạn quan tâm')
                        elif abs(rental_price - user_prefs['price_range']['avg']) < 500000:
                            preference_bonus *= 1.1
                            preference_reasons.append('Giá gần với lịch sử xem của bạn')
            
            # TIME-BASED BOOST
            time_bonus = 1.0
            if context.get('time_of_day') == 'morning' and user_prefs and \
               user_prefs.get('avg_duration', 0) > 30:
                time_bonus = 1.05
            
            # Apply all bonuses
            final_score = score * location_bonus * preference_bonus * time_bonus
            
            # Build explanation
            explanation = {
                'collaborative': 'Người dùng tương tự đã xem bài này',
                'location': location_reason,
                'preference': preference_reasons,
                'interaction_count': f'Bạn đã xem {user_prefs["total_interactions"] if user_prefs else 0} bài tương tự' if user_prefs else None,
            }
            
            # Filter out None reasons
            explanation = {k: v for k, v in explanation.items() if v}
            
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
                'explanation': explanation,
                'confidence': min(1.0, float(user_similarities[similar_users_idx[0]]) * preference_bonus) if len(similar_users_idx) > 0 else 0.5,
            })
        
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
            
            # LOCATION PROXIMITY BONUS
            location_bonus = 1.0
            distance = None
            location_reason = None
            
            if use_location and ref_location[0] != 0 and ref_location[1] != 0:
                rental_coords = self.rental_coordinates.get(rental_id, (0, 0))
                
                if rental_coords[0] != 0 and rental_coords[1] != 0:
                    distance = self._haversine_distance(
                        ref_location[0], ref_location[1],
                        rental_coords[0], rental_coords[1]
                    )
                    
                    # Gần nhất có bonus cao hơn
                    if distance <= 5:  # 5km
                        location_bonus = 1.0 + (1.0 - distance / 5.0) * 0.3
                        location_reason = f'Gần bài đăng gốc ({distance:.1f}km)'
                    else:
                        location_bonus = max(0.7, 1.0 - distance / 50.0)
            
            final_score = base_score * location_bonus
            
            # Build explanation
            explanation = {
                'content': 'Có nội dung tương tự bài bạn đang xem',
                'location': location_reason,
            }
            
            explanation = {k: v for k, v in explanation.items() if v}
            
            recommendations.append({
                'rentalId': rental_id,
                'score': base_score,
                'locationBonus': location_bonus,
                'finalScore': final_score,
                'method': 'content_based_similar',
                'coordinates': self.rental_coordinates.get(rental_id, (0, 0)),
                'distance_km': distance,
                'explanation': explanation,
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
    
    # 1. Load data
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
    
    # 2. Train model
    model = RecommendationModel()
    model.train(interactions_df, rentals_df)
    
    # 3. Test recommendations
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
    
    # 4. Save model
    model.save('./models/recommendation_model.pkl')
    
    print("\n" + "="*70)
    print("✅ TRAINING PIPELINE COMPLETED")
    print("="*70 + "\n")
    print("Next steps:")
    print("1. Start FastAPI server: python app/main.py")
    print("2. Test API: curl http://localhost:8001/health")
    print("3. Get recommendations: POST http://localhost:8001/recommend/personalized")
    print()


if __name__ == '__main__':
    main()