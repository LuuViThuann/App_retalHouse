import os
import sys
import pandas as pd
from pymongo import MongoClient
from datetime import datetime, timedelta
from dotenv import load_dotenv

load_dotenv()


class DatasetExporter:
    def __init__(self):
        self.mongo_uri = os.getenv('MONGODB_URI', 'mongodb://localhost:27017/renthouse')
        print(f"\n📍 Connecting to MongoDB: {self.mongo_uri}")
        
        try:
            self.client = MongoClient(self.mongo_uri, serverSelectionTimeoutMS=5000)
            self.client.admin.command('ping')
            print("✅ MongoDB Connected\n")
        except Exception as e:
            print(f"❌ MongoDB Connection Failed: {e}")
            raise
        
        self.db = self._get_database()
        print(f"   Using database: {self.db.name}\n")
    
    def _get_database(self):
        """Extract database name từ URI hoặc dùng default"""
        try:
            db = self.client.get_default_database()
            return db
        except Exception as e:
            print(f"   ⚠️ get_default_database failed: {e}")
            print("   Using fallback: rental_app")
            return self.client['rental_app']
    
    def _get_rental_coordinates(self, rental_id):
        """Lấy coordinates từ rental bằng rentalId"""
        try:
            from bson.objectid import ObjectId
            
            # Convert string to ObjectId nếu cần
            if isinstance(rental_id, str):
                try:
                    rental_id = ObjectId(rental_id)
                except:
                    pass
            
            rental = self.db.rentals.find_one({'_id': rental_id})
            
            if rental and rental.get('location', {}).get('coordinates', {}).get('coordinates'):
                coords = rental['location']['coordinates']['coordinates']
                return {
                    'longitude': float(coords[0]) if len(coords) > 0 else 0,
                    'latitude': float(coords[1]) if len(coords) > 1 else 0,
                }
            
            return {'longitude': 0, 'latitude': 0}
            
        except Exception as e:
            print(f"      ⚠️ Error getting coordinates: {e}")
            return {'longitude': 0, 'latitude': 0}
    
    def export_interactions(self, output_path='./data/interactions.csv', days=180):
        """
        📊 Enhanced interaction logging
        Giải quyết vấn đề: 6,879 views / 83 favorites / 27 unfavorites (thiếu diversity)
        
        Thêm interaction types:
        - scroll: User scroll tới cuối trang (interest level +1)
        - filter_apply: User áp dụng filter (specific intent +1.5)
        - detail_open: User xem chi tiết (high interest +3)
        - contact: User click liên hệ (conversion +8)
        - call: User click call (strong intent +10)
        """
        print(f"📊 Exporting interactions (last {days} days)...\n")
        
        cutoff_date = datetime.utcnow() - timedelta(days=days)
        
        interactions = list(self.db.userinteractions.find({
            'timestamp': {'$gte': cutoff_date}
        }).sort('timestamp', -1).limit(100000))
        
        print(f"   ✅ Found {len(interactions)} interactions\n")
        
        # 🔥 ENHANCED INTERACTION SCORING
        interaction_score_map = {
            'view': 1,              # Baseline
            'scroll': 2,            # 🆕 Viewed full page
            'filter_apply': 1.5,    # 🆕 Applying specific filter
            'detail_open': 3,       # 🆕 Opened detail page
            'click': 2,
            'favorite': 5,
            'unfavorite': -3,       # Negative signal (IMPORTANT!)
            'share': 4,
            'contact': 8,           # 🆕 Clicked contact
            'call': 10,             # 🆕 Called owner
        }
        
        enriched_interactions = []
        print("   🔄 Adding coordinates and enhanced interaction types...\n")
        
        for i, interaction in enumerate(interactions):
            # Get coordinates
            rental_id = interaction.get('rentalId')
            coords = self._get_rental_coordinates(rental_id)
            
            interaction['longitude'] = coords['longitude']
            interaction['latitude'] = coords['latitude']
            
            # 🔥 ENHANCED SCORING
            interaction_type = interaction.get('interactionType', 'view')
            interaction['interactionScore'] = interaction_score_map.get(interaction_type, 1)
            
            enriched_interactions.append(interaction)
            
            if (i + 1) % 500 == 0:
                print(f"      ⏳ Processed {i+1}/{len(interactions)}...")
        
        df = pd.DataFrame(enriched_interactions)
        
        # Data cleaning
        if '_id' in df.columns:
            df = df.drop('_id', axis=1)
        
        df['userId'] = df['userId'].astype(str)
        df['rentalId'] = df['rentalId'].astype(str)
        df['timestamp'] = pd.to_datetime(df['timestamp'])
        
        df['longitude'] = pd.to_numeric(df['longitude'], errors='coerce').fillna(0)
        df['latitude'] = pd.to_numeric(df['latitude'], errors='coerce').fillna(0)
        
        # Extract rental snapshot
        print(f"\n   📸 Extracting rental snapshot data...")
        
        if 'rentalSnapshot' in df.columns:
            df['price'] = df['rentalSnapshot'].apply(
                lambda x: x.get('price', 0) if isinstance(x, dict) else 0
            )
            df['propertyType'] = df['rentalSnapshot'].apply(
                lambda x: x.get('propertyType', 'unknown') if isinstance(x, dict) else 'unknown'
            )
            df['location_text'] = df['rentalSnapshot'].apply(
                lambda x: x.get('location', 'unknown') if isinstance(x, dict) else 'unknown'
            )
            df['area'] = df['rentalSnapshot'].apply(
                lambda x: x.get('area', 0) if isinstance(x, dict) else 0
            )
        
        # Extract context
        print(f"   🔍 Extracting context data...\n")
        
        if 'contextData' in df.columns:
            df['timeOfDay'] = df['contextData'].apply(
                lambda x: x.get('timeOfDay', 'morning') if isinstance(x, dict) else 'morning'
            )
            df['deviceType'] = df['contextData'].apply(
                lambda x: x.get('deviceType', 'mobile') if isinstance(x, dict) else 'mobile'
            )
            df['searchRadius'] = df['contextData'].apply(
                lambda x: x.get('searchRadius', 10) if isinstance(x, dict) else 10
            )
        
        # Select columns
        required_columns = [
            'userId', 'rentalId', 'interactionType', 'interactionScore',
            'price', 'propertyType', 'location_text', 'area', 'timestamp',
            'longitude', 'latitude',
            'duration', 'scrollDepth', 'deviceType',
            'timeOfDay', 'searchRadius'
        ]
        
        available_cols = [col for col in required_columns if col in df.columns]
        df = df[available_cols]
        
        df = df.dropna(subset=['userId', 'rentalId', 'interactionType'])
        
        print(f"✅ Cleaned data: {len(df)} records")
        print(f"   Columns: {df.columns.tolist()}")
        print(f"   Unique users: {df['userId'].nunique()}")
        print(f"   Unique rentals: {df['rentalId'].nunique()}")
        print(f"   Interaction types: {df['interactionType'].unique().tolist()}\n")
        
        # 🔥 INTERACTION TYPE DISTRIBUTION
        print(f"   📊 Interaction Distribution:")
        type_dist = df['interactionType'].value_counts()
        for itype, count in type_dist.items():
            score = interaction_score_map.get(itype, 1)
            print(f"      {itype}: {count:,} (score weight: {score})")
        print()
        
        valid_coords = len(df[(df['longitude'] != 0) & (df['latitude'] != 0)])
        print(f"   ✅ Valid coordinates: {valid_coords}/{len(df)} ({100*valid_coords/len(df):.2f}%)\n")
        
        # Save
        os.makedirs(os.path.dirname(output_path) or '.', exist_ok=True)
        df.to_csv(output_path, index=False)
        print(f"✅ Exported {len(df)} interactions to {output_path}\n")
        
        return df
            
    
    def export_rentals(self, output_path='./data/rentals.csv'):  # ← 4 spaces
        """Export rentals với coordinates và userId - 🔥 UPDATED"""  # ← 8 spaces
        print("🏠 Exporting rentals...\n")  # ← 8 spaces
        
        try:  # ← 8 spaces
            print("   Fetching rentals with status='available'...")
            self.db.rentals.create_index([('status', 1), ('createdAt', -1)])
            
            # 🔥 FIX: INCLUDE 'userId' field in projection
            rentals = list(self.db.rentals.find(
                {'status': 'available'},
                {
                    '_id': 1, 
                    'userId': 1,  # 🔥 ADD userId
                    'price': 1, 
                    'location': 1,
                    'propertyType': 1, 
                    'area': 1,
                    'amenities': 1,
                    'furniture': 1,
                    'images': 1,
                    'videos': 1,
                    'title': 1,
                    'status': 1,
                    'createdAt': 1
                }
            ).limit(5000))
            
            print(f"   Found {len(rentals)} available rentals")
            
            if len(rentals) == 0:
                print("   ⚠️ No 'available' rentals found, fetching ALL...")
                rentals = list(self.db.rentals.find().limit(5000))
                print(f"   Found {len(rentals)} total rentals")
            
            if len(rentals) == 0:
                print("⚠️ No rentals found!")
                print(f"   Collections in database: {self.db.list_collection_names()}")
                return pd.DataFrame()
            
            df = pd.DataFrame(rentals)
            
            # Convert _id to string
            if '_id' in df.columns:
                df['_id'] = df['_id'].astype(str)
            
            # 🔥 NEW: Convert userId to string
            if 'userId' in df.columns:
                df['userId'] = df['userId'].astype(str)
                print(f"   ✅ userId field processed: {df['userId'].nunique()} unique owners")
            else:
                print("   ⚠️ No userId field in data, creating empty column")
                df['userId'] = ''
            
            # 🔥 EXTRACT COORDINATES
            print("   📍 Extracting coordinates...")
            
            df['longitude'] = df['location'].apply(
                lambda x: float(x.get('coordinates', {}).get('coordinates', [0, 0])[0]) 
                if isinstance(x, dict) else 0
            )
            df['latitude'] = df['location'].apply(
                lambda x: float(x.get('coordinates', {}).get('coordinates', [0, 0])[1]) 
                if isinstance(x, dict) else 0
            )
            
            valid_coords = len(df[(df['longitude'] != 0) & (df['latitude'] != 0)])
            print(f"      Valid coordinates: {valid_coords}/{len(df)} ({100*valid_coords/len(df):.2f}%)")
            print(f"      Longitude range: {df['longitude'].min():.4f} to {df['longitude'].max():.4f}")
            print(f"      Latitude range: {df['latitude'].min():.4f} to {df['latitude'].max():.4f}\n")
            
            # Extract location text
            df['location_short'] = df['location'].apply(
                lambda x: x.get('short', '') if isinstance(x, dict) else ''
            )
            df['location_full'] = df['location'].apply(
                lambda x: x.get('fullAddress', '') if isinstance(x, dict) else ''
            )
            
            # Extract area with error handling
            print("   📏 Extracting area data...")
            
            if 'area' in df.columns:
                df['area_total'] = df['area'].apply(
                    lambda x: float(x.get('total', 0)) if isinstance(x, dict) and x else 0
                )
                df['area_bedrooms'] = df['area'].apply(
                    lambda x: int(x.get('bedrooms', 0)) if isinstance(x, dict) and x else 0
                )
                df['area_bathrooms'] = df['area'].apply(
                    lambda x: int(x.get('bathrooms', 0)) if isinstance(x, dict) and x else 0
                )
            else:
                print("      ⚠️ 'area' field not found in data, using defaults")
                df['area_total'] = 0
                df['area_bedrooms'] = 0
                df['area_bathrooms'] = 0
            
            # Count features
            print("   🎨 Counting features...")
            df['amenities_count'] = df['amenities'].apply(
                lambda x: len(x) if isinstance(x, list) else 0
            )
            df['furniture_count'] = df['furniture'].apply(
                lambda x: len(x) if isinstance(x, list) else 0
            )
            df['images_count'] = df['images'].apply(
                lambda x: len(x) if isinstance(x, list) else 0
            )
            df['videos_count'] = df['videos'].apply(
                lambda x: len(x) if isinstance(x, list) else 0
            )
            
            # 🔥 UPDATE: Select columns including userId
            selected_columns = [
                '_id', 'userId', 'title', 'price', 'propertyType', 'status',
                'location_short', 'location_full',
                'longitude', 'latitude',
                'area_total', 'area_bedrooms', 'area_bathrooms',
                'amenities_count', 'furniture_count', 'images_count', 'videos_count',
                'createdAt'
            ]
            
            available_cols = [col for col in selected_columns if col in df.columns]
            df = df[available_cols]
            
            # Ensure price is numeric
            df['price'] = pd.to_numeric(df['price'], errors='coerce').fillna(0)
            
            print(f"\n✅ Cleaned data: {len(df)} rentals, {len(df.columns)} columns")
            print(f"   Columns: {df.columns.tolist()}\n")
            print(f"   Property types: {df['propertyType'].unique().tolist()}")
            print(f"   Price range: {df['price'].min():.0f} - {df['price'].max():.0f}")
            print(f"   🔥 Unique owners: {df['userId'].nunique()}\n")
            
            os.makedirs(os.path.dirname(output_path) or '.', exist_ok=True)
            df.to_csv(output_path, index=False)
            print(f"✅ Exported {len(df)} rentals to {output_path}\n")
            
            return df
            
        except Exception as e:
            print(f"❌ Error exporting rentals: {e}")
            import traceback
            traceback.print_exc()
            raise
    
    def validate_data(self, interactions_df, rentals_df):  
        """Validate dữ liệu sau export"""
        print("=" * 70)
        print("📋 DATA VALIDATION")
        print("=" * 70 + "\n")
        
        print("✅ INTERACTIONS DATA:")
        print(f"   Total records: {len(interactions_df)}")
        print(f"   Unique users: {interactions_df['userId'].nunique()}")
        print(f"   Unique rentals: {interactions_df['rentalId'].nunique()}")
        print(f"   Interaction types: {interactions_df['interactionType'].value_counts().to_dict()}")
        print(f"   Date range: {interactions_df['timestamp'].min()} to {interactions_df['timestamp'].max()}")
        print(f"   Score range: {interactions_df['interactionScore'].min():.2f} to {interactions_df['interactionScore'].max():.2f}")
        
        valid_coords = len(interactions_df[(interactions_df['longitude'] != 0) & (interactions_df['latitude'] != 0)])
        print(f"   ✅ Coordinates: {valid_coords}/{len(interactions_df)} ({100*valid_coords/len(interactions_df):.2f}% valid)")
        
        print("\n✅ RENTALS DATA:")
        print(f"   Total rentals: {len(rentals_df)}")
        print(f"   Property types: {rentals_df['propertyType'].value_counts().to_dict()}")
        print(f"   Price range: {rentals_df['price'].min():.0f} - {rentals_df['price'].max():.0f}")
        print(f"   Avg price: {rentals_df['price'].mean():.0f}")
        
        valid_rental_coords = len(rentals_df[(rentals_df['longitude'] != 0) & (rentals_df['latitude'] != 0)])
        print(f"   ✅ Coordinates: {valid_rental_coords}/{len(rentals_df)} ({100*valid_rental_coords/len(rentals_df):.2f}% valid)")
        
        # 🔥 FIX: Xóa warning sparsity (sẽ calculate sau khi train)
        # KHÔNG in warning ở đây vì chưa build matrix
        
        print("\n" + "=" * 70 + "\n")
    
    def export_all(self):  # ← 4 spaces (PHẢI cùng level với validate_data)
        """Export tất cả dữ liệu"""
        print("\n" + "=" * 70)
        print("🚀 STARTING DATA EXPORT WITH COORDINATES")
        print("=" * 70 + "\n")
        
        try:
            interactions_df = self.export_interactions()
            rentals_df = self.export_rentals()
            
            if len(interactions_df) > 0 and len(rentals_df) > 0:
                self.validate_data(interactions_df, rentals_df)
                
                print("=" * 70)
                print("✅ EXPORT COMPLETED SUCCESSFULLY")
                print("=" * 70)
                print(f"\n📊 Ready for training:")
                print(f"   Interactions: {len(interactions_df)} rows (with coordinates)")
                print(f"   Rentals: {len(rentals_df)} rows (with coordinates)")
                print(f"\n📌 Next step: python training/train_model.py\n")
            else:
                print("❌ EXPORT FAILED - No data exported")
                return None, None
            
            return interactions_df, rentals_df
            
        except Exception as e:
            print(f"\n❌ EXPORT FAILED: {e}")
            import traceback
            traceback.print_exc()
            return None, None


if __name__ == '__main__':  # ← 0 spaces (no indentation)
    try:
        exporter = DatasetExporter()
        exporter.export_all()
    except KeyboardInterrupt:
        print("\n\n⚠️ Export interrupted by user")
    except Exception as e:
        print(f"\n\n❌ Export failed: {e}")
        sys.exit(1)