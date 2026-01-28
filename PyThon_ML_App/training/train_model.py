import os
import sys
import pandas as pd
import numpy as np
import joblib
from datetime import datetime
from sklearn.metrics.pairwise import cosine_similarity
from sklearn.preprocessing import StandardScaler, LabelEncoder
from scipy.sparse import csr_matrix
from math import radians, sin, cos, sqrt, atan2

sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

class RecommendationModel:
    """🎯 Improved Recommendation Engine with Hybrid Approach"""
    
    def __init__(self):
        self.user_item_matrix = None
        self.user_similarity = None
        self.item_similarity = None
        self.user_features = {}
        self.item_features = {}
        self.user_encoder = LabelEncoder()
        self.item_encoder = LabelEncoder()
        self.scaler = StandardScaler()
        
        # Geographic data
        self.rental_coordinates = {}
        self.user_locations = {}
        self.rental_owners = {}
        
        # Popularity & interaction data
        self.popularity_scores = {}
        self.interactions_df = None
        
        # 🔥 FIX: Initialize matrix_sparsity & matrix_density
        self.matrix_sparsity = 0.0  # Default value
        self.matrix_density = 0.0   # Default value
        
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
        for _, row in rentals_df.iterrows():
            rental_id = str(row['_id'])
            lon = float(row.get('longitude', 0))
            lat = float(row.get('latitude', 0))
            self.rental_coordinates[rental_id] = (lon, lat)
            
            # Store rental ownership
            if 'userId' in row and pd.notna(row['userId']):
                self.rental_owners[rental_id] = str(row['userId'])
        
        print(f"      Stored {len(self.rental_coordinates)} rental coordinates")
        print(f"      Stored {len(self.rental_owners)} rental ownerships")
        
        # Calculate user location centroids
        print("   👥 Calculating user location centroids...")
        self._calculate_user_locations(valid_interactions)
        
        # Encode users and items
        valid_interactions['user_idx'] = self.user_encoder.fit_transform(valid_interactions['userId'])
        valid_interactions['item_idx'] = self.item_encoder.fit_transform(valid_interactions['rentalId'])
        
        print(f"   Encoded {len(self.user_encoder.classes_)} users")
        print(f"   Encoded {len(self.item_encoder.classes_)} items")
        
        return valid_interactions, rentals_df
    
    def _calculate_user_locations(self, interactions_df):
        """Tính vị trí centroid của mỗi user"""
        try:
            for user_id in interactions_df['userId'].unique():
                user_interactions = interactions_df[interactions_df['userId'] == user_id]
                
                valid_coords = []
                for _, row in user_interactions.iterrows():
                    rental_id = str(row['rentalId'])
                    if rental_id in self.rental_coordinates:
                        coords = self.rental_coordinates[rental_id]
                        if coords[0] != 0 and coords[1] != 0:
                            valid_coords.append(coords)
                
                if valid_coords:
                    avg_lon = np.mean([c[0] for c in valid_coords])
                    avg_lat = np.mean([c[1] for c in valid_coords])
                    self.user_locations[user_id] = (avg_lon, avg_lat)
            
            print(f"      Calculated locations for {len(self.user_locations)} users")
        
        except Exception as e:
            print(f"      ⚠️ Error calculating user locations: {e}")
    

    def build_user_item_matrix(self, interactions_df):
        """
        🔨 BUILD USER-ITEM MATRIX
        Phải initialize matrix_sparsity ở đây
        """
        print("\n🔨 Building User-Item Matrix...")
        
        # Get dimensions from encoder
        n_users = len(self.user_encoder.classes_)
        n_items = len(self.item_encoder.classes_)
        
        print(f"   Matrix size: {n_users} users × {n_items} items")
        
        # Aggregate interactions
        interaction_scores = interactions_df.groupby(['user_idx', 'item_idx'])['interactionScore'].sum().reset_index()
        
        # Create sparse matrix
        self.user_item_matrix = csr_matrix(
            (interaction_scores['interactionScore'], 
            (interaction_scores['user_idx'], interaction_scores['item_idx'])),
            shape=(n_users, n_items)
        )
        
        # 🔥 FIX: Calculate and store sparsity
        non_zero_cells = self.user_item_matrix.nnz
        total_cells = n_users * n_items
        
        # Correct sparsity calculation
        self.matrix_sparsity = 100 * (1 - non_zero_cells / max(total_cells, 1))
        self.matrix_density = 100 - self.matrix_sparsity
        
        print(f"\n   📊 SPARSITY ANALYSIS:")
        print(f"      Total cells: {total_cells:,}")
        print(f"      Non-zero cells: {non_zero_cells:,}")
        print(f"      ✅ Sparsity: {self.matrix_sparsity:.2f}%")
        print(f"      ✅ Density: {self.matrix_density:.2f}%")
        print(f"\n      Status: {'🔴 VERY SPARSE' if self.matrix_sparsity > 95 else '🟡 SPARSE' if self.matrix_sparsity > 85 else '🟢 ACCEPTABLE'}")
        print()
    
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
        
        # 1. Data validation
        print("\n📊 DATA VALIDATION:")
        print(f"   Total interactions: {len(interactions_df)}")
        print(f"   Unique users: {interactions_df['userId'].nunique()}")
        print(f"   Unique rentals: {interactions_df['rentalId'].nunique()}")
        
        # 2. Prepare data (encode users/items)
        print("\n📊 Preparing data...")
        interactions_df, rentals_df = self.prepare_data(interactions_df, rentals_df)
        
        # 🔥 CRITICAL: Phải call build_user_item_matrix()
        print("\n🔨 Building matrices...")
        self.build_user_item_matrix(interactions_df)
        
        # 3. Compute similarities
        print("\n🧮 Computing similarities...")
        self.compute_user_similarity()
        self.compute_item_similarity()
        
        # 4. Compute popularity
        print("\n⭐ Computing popularity scores...")
        self.compute_popularity_scores(interactions_df)
        
        # 5. Extract item features
        print("\n📋 Extracting item features...")
        self.item_features = {}
        
        for idx, row in rentals_df.iterrows():
            try:
                rental_id = str(row['_id'])
                self.item_features[rental_id] = {
                    'price': float(row['price']) if pd.notna(row['price']) else 0,
                    'propertyType': str(row['propertyType']) if pd.notna(row['propertyType']) else 'unknown',
                    'location_text': str(row.get('location_short', 'unknown')) if 'location_short' in row and pd.notna(row.get('location_short')) else 'unknown',
                    'area_total': float(row.get('area_total', 0)) if 'area_total' in row and pd.notna(row.get('area_total')) else 0,
                    'amenities_count': int(row.get('amenities_count', 0)) if 'amenities_count' in row else 0,
                    'longitude': float(row.get('longitude', 0)) if 'longitude' in row else 0,
                    'latitude': float(row.get('latitude', 0)) if 'latitude' in row else 0,
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
        print(f"   👥 Users: {len(self.user_encoder.classes_)}")
        print(f"   🏠 Items: {len(self.item_encoder.classes_)}")
        print(f"   📊 Interactions: {self.user_item_matrix.nnz}")
        print(f"   📉 Sparsity: {self.matrix_sparsity:.2f}%")
        print(f"   📍 Rental coordinates: {len(self.rental_coordinates)}")
        print(f"   👤 User locations: {len(self.user_locations)}")
        print(f"   🏢 Item features: {len(self.item_features)}")
        print()


    def recommend_for_user(self, user_id, n_recommendations=10, exclude_items=None, 
                        use_location=True, radius_km=20, context=None):
        """
        🎯 IMPROVED HYBRID RECOMMENDATION ENGINE
        
        **Major Improvements:**
        1. ✅ Adaptive weights based on data sparsity
        2. ✅ Proper confidence calculation (0.3-0.95 range)
        3. ✅ Enhanced content-based scoring
        4. ✅ Better price matching logic
        5. ✅ Exclude user's own rentals automatically
        6. ✅ Detailed scoring breakdown for explainability
        """
        
        context = context or {}
        exclude_items = set(exclude_items or [])
        
        # Get user data
        user_location = self.user_locations.get(user_id)
        user_prefs = self.get_user_preferences(user_id)
        
        # Exclude user's own rentals
        user_own_rentals = {
            rental_id for rental_id, owner_id in self.rental_owners.items()
            if owner_id == user_id
        }
        exclude_items.update(user_own_rentals)
        
        # Determine adaptive weights
        matrix_sparsity = getattr(self, 'matrix_sparsity', 0.0)
        total_interactions = user_prefs.get('total_interactions', 0) if user_prefs else 0
        
        if matrix_sparsity > 60:
            weights = {
                'popularity': 0.30,
                'content': 0.50,
                'cf': 0.20
            }
            strategy = 'content-focused'
            print(f"   ⚠️ High sparsity ({matrix_sparsity:.1f}%) → Using content-focused weights")
        elif total_interactions >= 30:
            weights = {
                'popularity': 0.20,
                'content': 0.35,
                'cf': 0.45
            }
            strategy = 'cf-focused'
            print(f"   👤 Experienced user ({total_interactions} interactions) → Using CF-focused weights")
        else:
            weights = {
                'popularity': 0.25,
                'content': 0.40,
                'cf': 0.35
            }
            strategy = 'balanced'
        
        print(f"\n🎯 RECOMMEND (Hybrid {strategy.upper()})")
        print(f"   User: {user_id}")
        print(f"   Weights: Pop={weights['popularity']:.0%}, Content={weights['content']:.0%}, CF={weights['cf']:.0%}")
        print(f"   Data: {len(self.user_encoder.classes_)} users, {len(self.item_encoder.classes_)} rentals")
        print(f"   Matrix sparsity: {matrix_sparsity:.1f}%")
        print(f"   Excluding: {len(exclude_items)} items (own rentals + seen)")
        
        # Score all candidates
        candidate_scores = {}
        
        user_exists = user_id in self.user_encoder.classes_
        if user_exists:
            user_idx = self.user_encoder.transform([user_id])[0]
        
        for item_idx, rental_id in enumerate(self.item_encoder.classes_):
            rental_id = str(rental_id)
            
            if rental_id in exclude_items or rental_id in context.get('impressions', []):
                continue
            
            if user_exists and self.user_item_matrix[user_idx, item_idx] > 0:
                continue
            
            # Calculate scores
            popularity_score = self.popularity_scores.get(rental_id, 0) / 100
            content_score = self._calculate_content_score(rental_id, user_prefs)
            
            cf_score = 0
            if user_exists and len(self.user_encoder.classes_) >= 5:
                try:
                    cf_score = self._calculate_cf_score(user_idx, item_idx)
                except Exception:
                    cf_score = 0
            
            # Hybrid base score
            hybrid_score = (
                popularity_score * weights['popularity'] +
                content_score * weights['content'] +
                cf_score * weights['cf']
            )
            
            # Location bonus
            location_bonus = 1.0
            distance_km = None
            if use_location and user_location and rental_id in self.rental_coordinates:
                location_bonus, distance_km = self._calculate_location_bonus(
                    self.rental_coordinates[rental_id],
                    user_location,
                    radius_km
                )
            
            # Other bonuses
            preference_bonus = self._calculate_preference_bonus(rental_id, user_prefs)
            time_bonus = self._calculate_time_bonus(user_id, context)
            
            # Final score
            final_score = hybrid_score * location_bonus * preference_bonus * time_bonus
            
            # Calculate confidence
            confidence = self._calculate_confidence(
                content_score=content_score,
                cf_score=cf_score,
                popularity_score=popularity_score,
                user_prefs=user_prefs,
                location_bonus=location_bonus,
                total_interactions=total_interactions
            )
            
            candidate_scores[rental_id] = {
                'final_score': final_score,
                'hybrid_score': hybrid_score,
                'popularity': popularity_score,
                'content_score': content_score,
                'cf_score': cf_score,
                'location_bonus': location_bonus,
                'preference_bonus': preference_bonus,
                'time_bonus': time_bonus,
                'distance_km': distance_km,
                'confidence': confidence,
                'weights': weights,
                'strategy': strategy
            }
        
        # Sort and select top N
        sorted_items = sorted(
            candidate_scores.items(),
            key=lambda x: x[1]['final_score'],
            reverse=True
        )
        
        # Build recommendations
        recommendations = []
        
        for rental_id, scores in sorted_items[:n_recommendations]:
            coords = self.rental_coordinates.get(rental_id, (0, 0))
            
            recommendation = {
                'rentalId': rental_id,
                'score': float(scores['hybrid_score']),
                'popularityScore': float(scores['popularity']),
                'contentScore': float(scores['content_score']),
                'cfScore': float(scores['cf_score']),
                'locationBonus': float(scores['location_bonus']),
                'preferenceBonus': float(scores['preference_bonus']),
                'timeBonus': float(scores['time_bonus']),
                'finalScore': float(scores['final_score']),
                'confidence': float(scores['confidence']),
                'method': f'hybrid_{strategy}',
                'weights': scores['weights'],
                'coordinates': coords,
                'distance_km': float(scores['distance_km']) if scores['distance_km'] else None,
                'scoreBreakdown': {
                    'popularity': {
                        'score': float(scores['popularity']),
                        'weight': float(weights['popularity']),
                        'contribution': float(scores['popularity'] * weights['popularity'])
                    },
                    'content': {
                        'score': float(scores['content_score']),
                        'weight': float(weights['content']),
                        'contribution': float(scores['content_score'] * weights['content'])
                    },
                    'collaborative': {
                        'score': float(scores['cf_score']),
                        'weight': float(weights['cf']),
                        'contribution': float(scores['cf_score'] * weights['cf'])
                    }
                }
            }
            
            recommendations.append(recommendation)
        
        # Log summary
        print(f"   ✅ Generated {len(recommendations)} recommendations")
        
        if recommendations:
            top = recommendations[0]
            print(f"   🥇 Top recommendation:")
            print(f"      rentalId: {top['rentalId'][:16]}...")
            print(f"      finalScore: {top['finalScore']:.2f}")
            print(f"      confidence: {top['confidence']:.2f} ({int(top['confidence']*100)}%)")
            print(f"      breakdown: Pop={top['scoreBreakdown']['popularity']['contribution']:.2f}, "
                  f"Content={top['scoreBreakdown']['content']['contribution']:.2f}, "
                  f"CF={top['scoreBreakdown']['collaborative']['contribution']:.2f}")
            
            if top['distance_km']:
                print(f"      distance: {top['distance_km']:.2f}km")
        
        return recommendations

# ================================ CẬP NHẬT HELPER MỚI 

    def _calculate_confidence(self, content_score, cf_score, popularity_score, 
                                user_prefs, location_bonus, total_interactions):
            """
            🎯 Calculate REALISTIC confidence score (0.3-0.95)
            
            Factors:
            1. Content match quality (40%)
            2. CF data availability (30%)
            3. User experience level (20%)
            4. Location accuracy (10%)
            """
            
            # Base confidence from content score (40%)
            base_confidence = content_score * 0.40
            
            # CF contribution (30%)
            if cf_score > 0:
                cf_confidence = cf_score * 0.30
            else:
                cf_confidence = 0.05
            
            # User experience bonus (20%)
            experience_factor = min(1.0, total_interactions / 50.0)
            experience_confidence = experience_factor * 0.20
            
            # Location accuracy bonus (10%)
            location_confidence = 0
            if location_bonus > 1.0:
                location_factor = min(1.0, (location_bonus - 1.0) / 0.5)
                location_confidence = location_factor * 0.10
            elif location_bonus < 1.0:
                location_confidence = (location_bonus - 0.5) * 0.10
            
            # Combine
            raw_confidence = (
                base_confidence +
                cf_confidence +
                experience_confidence +
                location_confidence
            )
            
            # Apply realistic bounds (0.3 - 0.95)
            confidence = max(0.30, min(0.95, raw_confidence))
            
            # Adjust for sparse matrix
            matrix_sparsity = getattr(self, 'matrix_sparsity', 0.0)
            if matrix_sparsity > 70:
                confidence *= 0.90
                confidence = max(0.30, confidence)
            
            return float(confidence)

    def _calculate_content_score(self, rental_id, user_prefs):
        """
        📊 IMPROVED CONTENT-BASED SCORING
        
        Adjusted weights: Price 40%, Type 35%, Location 25%
        """
        
        if not user_prefs:
            return 0.60
        
        rental = self.item_features.get(rental_id, {})
        if not rental:
            return 0.40
        
        # Calculate component scores
        price_score = self._price_match_score(
            rental.get('price', 0),
            user_prefs.get('price_range', {})
        )
        
        type_score = self._property_type_match_score(
            rental.get('propertyType', ''),
            user_prefs.get('property_type_distribution', {})
        )
        
        location_score = self._location_diversity_score(
            rental.get('longitude', 0),
            rental.get('latitude', 0),
            user_prefs.get('user_centroid_longitude', 0),
            user_prefs.get('user_centroid_latitude', 0)
        )
        
        # Combine with adjusted weights
        content_score = (
            price_score * 0.40 +
            type_score * 0.35 +
            location_score * 0.25
        )
        
        # Engagement bonus for experienced users
        total_interactions = user_prefs.get('total_interactions', 0)
        if total_interactions >= 30:
            content_score = min(1.0, content_score * 1.05)
        
        return min(1.0, max(0.0, content_score))

    def _price_match_score(self, rental_price, price_range):
        """
        💰 IMPROVED Price matching with clear penalty/bonus structure
        
        Logic:
        - Within range + near median → 0.90-0.95 (excellent)
        - Within range → 0.70-0.90 (good)
        - Cheaper than min → 0.70-0.95 (good to excellent)
        - More expensive → 0.15-0.60 (bad to acceptable)
        """
        
        if not price_range or rental_price == 0:
            return 0.50
        
        min_p = price_range.get('min', 0)
        max_p = price_range.get('max', float('inf'))
        avg_p = price_range.get('avg', 0)
        median_p = price_range.get('median', avg_p)
        
        if avg_p == 0:
            return 0.50
        
        # CASE 1: Within range
        if min_p <= rental_price <= max_p:
            # Very close to median (within 10%)
            if abs(rental_price - median_p) < median_p * 0.10:
                return 0.95
            
            # Close to average
            diff_from_avg = abs(rental_price - avg_p)
            max_diff = max(avg_p - min_p, max_p - avg_p, 1)
            score = 0.90 - (diff_from_avg / max_diff) * 0.20
            return max(0.70, score)
        
        # CASE 2: Cheaper (good!)
        elif rental_price < min_p:
            discount_percent = (min_p - rental_price) / min_p
            
            if discount_percent <= 0.10:
                return 0.85
            elif discount_percent <= 0.20:
                return 0.90
            elif discount_percent <= 0.30:
                return 0.95
            else:
                return 0.70
        
        # CASE 3: More expensive (penalty)
        else:
            overprice_percent = (rental_price - max_p) / max_p
            
            if overprice_percent <= 0.10:
                return 0.60
            elif overprice_percent <= 0.20:
                return 0.45
            elif overprice_percent <= 0.30:
                return 0.30
            else:
                return 0.15

    def _property_type_match_score(self, rental_type, type_distribution):
        """
        🏠 Property type preference matching
        
        Logic:
        - Top preference (≥60%) → 0.95
        - Strong preference (≥30%) → 0.75
        - Medium preference (≥10%) → 0.55
        - Low/no preference → 0.35
        """
        
        if not type_distribution or not rental_type:
            return 0.50
        
        total = sum(type_distribution.values())
        if total == 0:
            return 0.50
        
        percentage = type_distribution.get(rental_type, 0) / total
        
        if percentage >= 0.60:
            return 0.95
        elif percentage >= 0.30:
            return 0.75
        elif percentage >= 0.10:
            return 0.55
        else:
            return 0.35


    def _location_diversity_score(self, rental_lon, rental_lat, user_lon, user_lat):
        """
        🌍 Location diversity scoring
        
        Strategy: Encourage exploration while respecting familiarity
        - Very close (0-0.5km) → 0.60
        - Nearby (0.5-2km) → 0.90 (sweet spot)
        - Medium (2-5km) → 0.85
        - Far (5-10km) → 0.70
        - Very far (>10km) → 0.50
        """
        
        if rental_lon == 0 or rental_lat == 0:
            return 0.60
        
        if user_lon == 0 or user_lat == 0:
            return 0.70
        
        dist = self._haversine_distance(user_lon, user_lat, rental_lon, rental_lat)
        
        if dist <= 0.5:
            return 0.60
        elif dist <= 2:
            return 0.90
        elif dist <= 5:
            return 0.85
        elif dist <= 10:
            return 0.70
        else:
            return 0.50


    def _amenity_match_score(self, amenities_count, avg_amenities):
        """🏢 Amenities richness"""
        if amenities_count == 0:
            return 0.4
        elif amenities_count <= 3:
            return 0.7
        elif amenities_count <= 6:
            return 0.9
        else:
            return 1.0
    
    def _calculate_location_bonus(self, rental_coords, user_location, radius_km):
        """
        📍 Calculate location bonus based on distance
        Returns: (location_bonus, distance_km)
        """
        if not rental_coords or not user_location:
            return 1.0, None
        
        rental_lon, rental_lat = rental_coords[0], rental_coords[1]
        user_lon, user_lat = user_location[0], user_location[1]
        
        # Check for invalid coordinates
        if rental_lon == 0 and rental_lat == 0:
            return 1.0, None
        if user_lon == 0 and user_lat == 0:
            return 1.0, None
        
        # Calculate distance
        distance_km = self._haversine_distance(user_lon, user_lat, rental_lon, rental_lat)
        
        # Calculate bonus based on distance and radius
        if distance_km <= radius_km:
            # Within radius: bonus increases as distance decreases
            if distance_km <= 1.0:  # Very close (< 1km)
                bonus = 1.3
            elif distance_km <= 3.0:  # Close (1-3km)
                bonus = 1.2
            elif distance_km <= 5.0:  # Medium (3-5km)
                bonus = 1.1
            else:  # Within radius but further (5km - radius_km)
                bonus = 1.0 + (1.0 - (distance_km / radius_km)) * 0.1
        else:
            # Outside radius: penalty increases with distance
            excess_distance = distance_km - radius_km
            if excess_distance <= 5.0:  # Just outside (0-5km)
                bonus = 0.9
            elif excess_distance <= 10.0:  # Moderately outside (5-10km)
                bonus = 0.7
            else:  # Far outside (> 10km)
                bonus = 0.5
        
        return max(0.1, min(1.5, bonus)), distance_km
    
    def _calculate_cf_score(self, user_idx, item_idx):
        """
        👥 Calculate Collaborative Filtering score
        Uses user-user similarity to predict item rating
        """
        try:
            if self.user_similarity is None or self.user_item_matrix is None:
                return 0.0
            
            # Get similar users (top K similar users)
            user_similarities = self.user_similarity[user_idx].toarray().flatten()
            
            # Get users who interacted with this item
            item_vector = self.user_item_matrix[:, item_idx].toarray().flatten()
            interacted_users = np.where(item_vector > 0)[0]
            
            if len(interacted_users) == 0:
                return 0.0
            
            # Weighted average of similar users' ratings
            numerator = 0.0
            denominator = 0.0
            
            for other_user_idx in interacted_users:
                similarity = user_similarities[other_user_idx]
                if similarity > 0:  # Only positive similarities
                    rating = item_vector[other_user_idx]
                    numerator += similarity * rating
                    denominator += abs(similarity)
            
            if denominator == 0:
                return 0.0
            
            # Normalize to 0-1 range
            cf_score = (numerator / denominator) / 10.0  # Assuming max interaction score is 10
            return min(1.0, max(0.0, cf_score))
            
        except Exception as e:
            print(f"      ⚠️ Error calculating CF score: {e}")
            return 0.0
    
    def _calculate_preference_bonus(self, rental_id, user_prefs):
        """
        🎯 Calculate preference bonus based on user's historical preferences
        """
        if not user_prefs:
            return 1.0
        
        rental = self.item_features.get(rental_id, {})
        if not rental:
            return 1.0
        
        bonus_factors = []
        
        # Property type match
        property_type = rental.get('propertyType', '')
        type_dist = user_prefs.get('property_type_distribution', {})
        if type_dist and property_type in type_dist:
            total = sum(type_dist.values())
            if total > 0:
                type_ratio = type_dist[property_type] / total
                if type_ratio >= 0.5:
                    bonus_factors.append(1.1)
                elif type_ratio >= 0.2:
                    bonus_factors.append(1.05)
                else:
                    bonus_factors.append(1.0)
            else:
                bonus_factors.append(1.0)
        else:
            bonus_factors.append(1.0)
        
        # Price range match
        rental_price = rental.get('price', 0)
        price_range = user_prefs.get('price_range', {})
        if price_range and rental_price > 0:
            avg_price = price_range.get('avg', 0)
            if avg_price > 0:
                price_ratio = rental_price / avg_price
                if 0.8 <= price_ratio <= 1.2:  # Within 20% of average
                    bonus_factors.append(1.1)
                elif 0.6 <= price_ratio <= 1.5:  # Within 50% of average
                    bonus_factors.append(1.05)
                else:
                    bonus_factors.append(1.0)
            else:
                bonus_factors.append(1.0)
        else:
            bonus_factors.append(1.0)
        
        # Calculate average bonus
        if bonus_factors:
            avg_bonus = np.mean(bonus_factors)
            return min(1.2, max(0.8, avg_bonus))
        
        return 1.0
    
    def _calculate_time_bonus(self, user_id, context):
        """
        ⏰ Calculate time-based bonus (recency, time of day, etc.)
        """
        if not context:
            return 1.0
        
        bonus = 1.0
        
        # Recency bonus: favor recently interacted items
        if 'recent_interactions' in context:
            recent_count = len(context.get('recent_interactions', []))
            if recent_count > 0:
                # Small bonus for active users
                bonus *= 1.05
        
        # Time of day bonus (if provided)
        if 'hour' in context:
            hour = context['hour']
            # Prefer morning/afternoon hours (8-18) for better engagement
            if 8 <= hour <= 18:
                bonus *= 1.02
        
        return min(1.1, max(0.9, bonus))
    
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
            
            # 🔥 FIX: Add all required fields for PersonalizedRecommendationResponse
            recommendations.append({
                'rentalId': rental_id,
                'score': float(score),
                'locationBonus': 1.0,        # 🔥 ADD: Default location bonus
                'preferenceBonus': 1.0,      # 🔥 ADD: Default preference bonus
                'timeBonus': 1.0,            # 🔥 ADD: Default time bonus
                'finalScore': float(score),  # 🔥 FIX: ADD finalScore (same as score)
                'method': 'popularity',
                'coordinates': self.rental_coordinates.get(rental_id, (0, 0)),
                'distance_km': None,         # 🔥 ADD: No distance for popularity
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
            'rental_owners': self.rental_owners,
            'matrix_sparsity': self.matrix_sparsity,  # 🔥 ADD
            'matrix_density': self.matrix_density,    # 🔥 ADD
            'trained_at': datetime.now().isoformat()
        }
        
        joblib.dump(model_data, filepath)
        
        print(f"✅ Model saved successfully")
        print(f"   File size: {os.path.getsize(filepath) / (1024*1024):.2f} MB")
        print(f"   Rental coordinates stored: {len(self.rental_coordinates)}")
        print(f"   User locations calculated: {len(self.user_locations)}")
        print(f"   🔥 Matrix sparsity saved: {self.matrix_sparsity:.2f}%")  # ← FIX

    # 🔥 UPDATE: load method to include rental_owners (line ~530)
    @classmethod
    def load(cls, filepath='./models/recommendation_model.pkl'):
        """Load model từ file"""
        print(f"\n📂 Loading model from {filepath}...")
        
        if not os.path.exists(filepath):
            raise FileNotFoundError(f"Model file not found: {filepath}")
        
        model_data = joblib.load(filepath)
        
        # ✅ FIX: Create instance properly
        model = cls()
        
        # ✅ Restore all attributes from saved model
        model.user_item_matrix = model_data['user_item_matrix']
        model.user_similarity = model_data['user_similarity']
        model.item_similarity = model_data['item_similarity']
        model.user_encoder = model_data['user_encoder']
        model.item_encoder = model_data['item_encoder']
        model.popularity_scores = model_data['popularity_scores']
        model.rental_coordinates = model_data.get('rental_coordinates', {})
        model.user_locations = model_data.get('user_locations', {})
        model.rental_owners = model_data.get('rental_owners', {})
        
        # 🔥 FIX: Restore matrix_sparsity with safe fallback
        if 'matrix_sparsity' in model_data:
            model.matrix_sparsity = model_data['matrix_sparsity']
            model.matrix_density = model_data['matrix_density']
        else:
            # Calculate if not in file
            n_users = len(model.user_encoder.classes_)
            n_items = len(model.item_encoder.classes_)
            total_cells = n_users * n_items
            non_zero_cells = model.user_item_matrix.nnz
            
            model.matrix_sparsity = 100 * (1 - non_zero_cells / max(total_cells, 1))
            model.matrix_density = 100 - model.matrix_sparsity
        
        print(f"✅ Model loaded successfully")
        print(f"   Trained at: {model_data.get('trained_at', 'unknown')}")
        print(f"   Rental coordinates loaded: {len(model.rental_coordinates)}")
        print(f"   User locations loaded: {len(model.user_locations)}")
        print(f"   🔥 Matrix sparsity: {model.matrix_sparsity:.2f}%")
        
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