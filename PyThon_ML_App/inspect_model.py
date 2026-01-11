import pickle
import os
import json
from tabulate import tabulate  # pip install tabulate

# Load model
model_path = "./models/recommendation_model.pkl"

if not os.path.exists(model_path):
    print(f"❌ Model not found: {model_path}")
    print("   Train the model first: python training/train_model.py")
    exit(1)

print("=" * 80)
print("📊 MODEL INSPECTION - WITH GEOGRAPHIC FEATURES")
print("=" * 80 + "\n")

# Load pickle file
with open(model_path, 'rb') as f:
    model = pickle.load(f)

print(f"✅ Model loaded successfully!")
print(f"   File size: {os.path.getsize(model_path) / (1024*1024):.2f} MB")
print(f"   Type: {type(model).__name__}\n")

# ==================== BASIC MODEL INFO ====================

print("=" * 80)
print("📋 MODEL STRUCTURE")
print("=" * 80 + "\n")

print("✅ Core Attributes:")
core_attrs = {
    'user_item_matrix': 'User-Item Interaction Matrix',
    'user_similarity': 'User-User Similarity Matrix',
    'item_similarity': 'Item-Item Similarity Matrix',
    'popularity_scores': 'Popularity Scores Dict',
    'user_encoder': 'User ID Encoder',
    'item_encoder': 'Rental ID Encoder',
}

for attr, desc in core_attrs.items():
    if hasattr(model, attr):
        value = getattr(model, attr)
        value_type = type(value).__name__
        
        if attr == 'user_item_matrix':
            print(f"   ✓ {attr} ({desc})")
            print(f"     - Shape: {value.shape}")
            print(f"     - Non-zero elements: {value.nnz}")
            print(f"     - Sparsity: {100 * (1 - value.nnz / (value.shape[0] * value.shape[1])):.2f}%")
        
        elif attr == 'popularity_scores':
            print(f"   ✓ {attr} ({desc})")
            print(f"     - Items: {len(value)}")
            print(f"     - Max score: {max(value.values()) if value else 0:.2f}")
            print(f"     - Min score: {min(value.values()) if value else 0:.2f}")
        
        elif attr in ['user_encoder', 'item_encoder']:
            print(f"   ✓ {attr}")
            classes = getattr(value, 'classes_', [])
            print(f"     - Classes: {len(classes)}")
        
        else:
            print(f"   ✓ {attr}")
            print(f"     - Type: {value_type}")

# ==================== 🔥 GEOGRAPHIC FEATURES ====================

print("\n" + "=" * 80)
print("🌍 GEOGRAPHIC FEATURES")
print("=" * 80 + "\n")

# Rental coordinates
if hasattr(model, 'rental_coordinates'):
    rental_coords = model.rental_coordinates
    print(f"✅ Rental Coordinates:")
    print(f"   Total rentals with coords: {len(rental_coords)}")
    
    if len(rental_coords) > 0:
        # Filter valid coordinates
        valid_coords = {k: v for k, v in rental_coords.items() if v[0] != 0 and v[1] != 0}
        print(f"   Valid coordinates: {len(valid_coords)} ({100*len(valid_coords)/len(rental_coords):.2f}%)")
        
        if valid_coords:
            # Get bounds
            lons = [v[0] for v in valid_coords.values()]
            lats = [v[1] for v in valid_coords.values()]
            
            print(f"   Geographic bounds:")
            print(f"     - Longitude: {min(lons):.4f} to {max(lons):.4f}")
            print(f"     - Latitude: {min(lats):.4f} to {max(lats):.4f}")
            
            # Sample rentals with coordinates
            print(f"\n   Sample rentals (first 5):")
            sample_data = []
            for i, (rental_id, (lon, lat)) in enumerate(list(valid_coords.items())[:5]):
                sample_data.append([
                    i+1,
                    rental_id[:16] + "...",
                    f"{lon:.4f}",
                    f"{lat:.4f}"
                ])
            
            print(tabulate(
                sample_data,
                headers=['#', 'Rental ID', 'Longitude', 'Latitude'],
                tablefmt='grid'
            ))
else:
    print("⚠️ rental_coordinates not found in model")

# User locations
print("\n✅ User Locations (Calculated Centroids):")

if hasattr(model, 'user_locations'):
    user_locs = model.user_locations
    print(f"   Users with calculated locations: {len(user_locs)}")
    
    if len(user_locs) > 0:
        # Get bounds
        lons = [v[0] for v in user_locs.values()]
        lats = [v[1] for v in user_locs.values()]
        
        print(f"   Geographic bounds:")
        print(f"     - Longitude: {min(lons):.4f} to {max(lons):.4f}")
        print(f"     - Latitude: {min(lats):.4f} to {max(lats):.4f}")
        
        # Sample users with locations
        print(f"\n   Sample user centroids (first 5):")
        sample_data = []
        for i, (user_id, (lon, lat)) in enumerate(list(user_locs.items())[:5]):
            sample_data.append([
                i+1,
                user_id[:16] + "...",
                f"{lon:.4f}",
                f"{lat:.4f}"
            ])
        
        print(tabulate(
            sample_data,
            headers=['#', 'User ID', 'Avg Longitude', 'Avg Latitude'],
            tablefmt='grid'
        ))
else:
    print("⚠️ user_locations not found in model")

# ==================== MATRIX STATS ====================

print("\n" + "=" * 80)
print("📊 MATRIX STATISTICS")
print("=" * 80 + "\n")

if hasattr(model, 'user_item_matrix'):
    matrix = model.user_item_matrix
    
    print(f"✅ User-Item Matrix:")
    print(f"   Dimensions: {matrix.shape[0]} users × {matrix.shape[1]} items")
    print(f"   Non-zero entries: {matrix.nnz}")
    print(f"   Sparsity: {100 * (1 - matrix.nnz / (matrix.shape[0] * matrix.shape[1])):.2f}%")
    print(f"   Average interactions per user: {matrix.nnz / matrix.shape[0]:.2f}")
    print(f"   Average interactions per item: {matrix.nnz / matrix.shape[1]:.2f}")

if hasattr(model, 'user_similarity'):
    sim = model.user_similarity
    print(f"\n✅ User Similarity Matrix:")
    print(f"   Shape: {sim.shape}")
    print(f"   Type: {type(sim).__name__}")

if hasattr(model, 'item_similarity'):
    sim = model.item_similarity
    print(f"\n✅ Item Similarity Matrix:")
    print(f"   Shape: {sim.shape}")
    print(f"   Type: {type(sim).__name__}")

# ==================== POPULARITY STATS ====================

print("\n" + "=" * 80)
print("⭐ POPULARITY STATISTICS")
print("=" * 80 + "\n")

if hasattr(model, 'popularity_scores'):
    pop = model.popularity_scores
    
    if pop:
        scores = list(pop.values())
        
        print(f"✅ Popularity Scores:")
        print(f"   Total items: {len(pop)}")
        print(f"   Max score: {max(scores):.2f}")
        print(f"   Min score: {min(scores):.2f}")
        print(f"   Average score: {sum(scores) / len(scores):.2f}")
        print(f"   Median score: {sorted(scores)[len(scores)//2]:.2f}")
        
        # Top 5 popular items
        print(f"\n   Top 10 Most Popular Rentals:")
        top_items = sorted(pop.items(), key=lambda x: x[1], reverse=True)[:10]
        
        sample_data = []
        for i, (rental_id, score) in enumerate(top_items):
            # Try to get coordinates if available
            coords = ""
            if hasattr(model, 'rental_coordinates') and rental_id in model.rental_coordinates:
                lon, lat = model.rental_coordinates[rental_id]
                if lon != 0 and lat != 0:
                    coords = f"({lon:.3f}, {lat:.3f})"
            
            sample_data.append([
                i+1,
                rental_id[:16] + "...",
                f"{score:.2f}",
                coords
            ])
        
        print(tabulate(
            sample_data,
            headers=['Rank', 'Rental ID', 'Popularity', 'Coordinates'],
            tablefmt='grid'
        ))

# ==================== ENCODERS INFO ====================

print("\n" + "=" * 80)
print("🔤 ENCODERS INFORMATION")
print("=" * 80 + "\n")

if hasattr(model, 'user_encoder'):
    encoder = model.user_encoder
    print(f"✅ User Encoder:")
    print(f"   Total users: {len(encoder.classes_)}")
    print(f"   Sample users (first 5): {list(encoder.classes_[:5])}")

if hasattr(model, 'item_encoder'):
    encoder = model.item_encoder
    print(f"\n✅ Item (Rental) Encoder:")
    print(f"   Total rentals: {len(encoder.classes_)}")
    print(f"   Sample rentals (first 5): {[str(x)[:12] + '...' for x in encoder.classes_[:5]]}")

# ==================== SUMMARY ====================

print("\n" + "=" * 80)
print("📈 GEOGRAPHIC COVERAGE SUMMARY")
print("=" * 80 + "\n")

coverage = {
    'Metric': [],
    'Value': [],
    'Percentage': []
}

total_rentals = len(model.item_encoder.classes_) if hasattr(model, 'item_encoder') else 0
total_users = len(model.user_encoder.classes_) if hasattr(model, 'user_encoder') else 0

if hasattr(model, 'rental_coordinates'):
    valid_rental_coords = len({k: v for k, v in model.rental_coordinates.items() if v[0] != 0 and v[1] != 0})
    coverage['Metric'].append('Rentals with valid coordinates')
    coverage['Value'].append(f"{valid_rental_coords}/{total_rentals}")
    coverage['Percentage'].append(f"{100*valid_rental_coords/max(total_rentals, 1):.2f}%")

if hasattr(model, 'user_locations'):
    coverage['Metric'].append('Users with calculated locations')
    coverage['Value'].append(f"{len(model.user_locations)}/{total_users}")
    coverage['Percentage'].append(f"{100*len(model.user_locations)/max(total_users, 1):.2f}%")

if len(coverage['Metric']) > 0:
    print(tabulate(
        [{
            'Metric': coverage['Metric'][i],
            'Value': coverage['Value'][i],
            'Percentage': coverage['Percentage'][i]
        } for i in range(len(coverage['Metric']))],
        headers='keys',
        tablefmt='grid'
    ))

# Ready for geographic recommendations
geo_ready = (
    hasattr(model, 'rental_coordinates') and 
    len(model.rental_coordinates) > 0 and
    hasattr(model, 'user_locations')
)

print(f"\n✅ Geographic Recommendations Ready: {geo_ready}")

print("\n" + "=" * 80)
print("✅ MODEL INSPECTION COMPLETE")
print("=" * 80 + "\n")

print("Next steps:")
print("1. Start API server: python app/main.py")
print("2. Test API: curl http://localhost:8001/health")
print("3. Get geo recommendations: POST /recommend/personalized")
print("4. View coordinates stats: GET /coordinates/stats")
print()