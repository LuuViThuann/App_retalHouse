import os
import sys
from typing import List, Optional, Tuple
from contextlib import asynccontextmanager
from fastapi import FastAPI, HTTPException, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
import redis
import json
from datetime import datetime, timedelta
from dotenv import load_dotenv

# Add parent directory to path
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from training.train_model import RecommendationModel

load_dotenv()

# ==================== PYDANTIC MODELS ====================

class Coordinates(BaseModel):
    """Geographic coordinates"""
    longitude: float = Field(..., description="Longitude (X coordinate)")
    latitude: float = Field(..., description="Latitude (Y coordinate)")

class RecommendRequest(BaseModel):
    userId: str = Field(..., description="User ID")
    n_recommendations: int = Field(default=10, ge=1, le=50, description="Number of recommendations")
    exclude_items: Optional[List[str]] = Field(None, description="List of rental IDs to exclude")
    filters: Optional[dict] = Field(None, description="Additional filters")
    use_location: bool = Field(default=True, description="Apply geographic filters")

class SimilarItemsRequest(BaseModel):
    rentalId: str = Field(..., description="Rental ID")
    n_recommendations: int = Field(default=10, ge=1, le=50)
    use_location: bool = Field(default=True, description="Apply geographic proximity bonus")

class PopularItemsRequest(BaseModel):
    n_recommendations: int = Field(default=10, ge=1, le=50)
    exclude_items: Optional[List[str]] = None

class RecommendationResponse(BaseModel):
    """Single recommendation with geographic data"""
    rentalId: str
    score: float
    method: str
    coordinates: Coordinates = Field(default=None, description="Rental coordinates for map display")
    locationBonus: float = Field(default=1.0, description="Geographic proximity bonus factor")
    finalScore: float = Field(default=None, description="Score after applying location bonus")
    distance_km: Optional[float] = Field(None, description="Distance from reference location in km")

class RecommendationsResult(BaseModel):
    """API response with multiple recommendations"""
    success: bool
    userId: Optional[str] = None
    recommendations: List[RecommendationResponse]
    count: int
    cached: bool = False
    generated_at: str
    model_info: Optional[dict] = Field(None, description="Model metadata")

# ==================== GLOBAL STATE ====================

model: Optional[RecommendationModel] = None
redis_client: Optional[redis.Redis] = None

# ==================== LIFESPAN EVENT HANDLERS ====================

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Lifespan context manager for startup and shutdown events."""
    global model, redis_client
    
    # ============ STARTUP ============
    print("\n" + "="*70)
    print("🚀 STARTING FASTAPI ML SERVICE WITH GEOGRAPHIC FEATURES")
    print("="*70 + "\n")
    
    # Load ML model
    model_path = os.getenv('MODEL_PATH', './models/recommendation_model.pkl')
    
    try:
        model = RecommendationModel.load(model_path)
        print("✅ ML Model loaded successfully")
        print(f"   - Users: {len(model.user_encoder.classes_)}")
        print(f"   - Rentals: {len(model.item_encoder.classes_)}")
        print(f"   - Rental coordinates: {len(model.rental_coordinates)}")
        print(f"   - User locations: {len(model.user_locations)}\n")
    except FileNotFoundError:
        print(f"⚠️ Model file not found: {model_path}")
        print("   Train the model first: python training/train_model.py\n")
        model = None
    except Exception as e:
        print(f"❌ Error loading model: {e}\n")
        model = None
    
    # Connect to Redis
    redis_url = os.getenv('REDIS_URL', 'redis://localhost:6379')
    
    try:
        redis_client = redis.from_url(redis_url, decode_responses=True)
        redis_client.ping()
        print("✅ Connected to Redis\n")
    except Exception as e:
        print(f"⚠️ Redis connection failed: {e}")
        print("   Continuing without cache\n")
        redis_client = None
    
    print("="*70)
    print("✅ SERVICE READY FOR GEOGRAPHIC RECOMMENDATIONS")
    print("="*70 + "\n")
    
    yield  # Application runs here
    
    # ============ SHUTDOWN ============
    if redis_client:
        redis_client.close()
        print("✅ Redis connection closed")

# ==================== FASTAPI APP ====================

app = FastAPI(
    title="Rental Recommendation API with Geographic Features",
    description="ML-powered recommendation service with location-aware suggestions",
    version="2.0.0",
    lifespan=lifespan
)

# ==================== CORS CONFIGURATION ====================

ALLOWED_ORIGINS = os.getenv(
    'ALLOWED_ORIGINS',
    'http://localhost:3000,http://localhost:8080'
).split(',')

ALLOWED_ORIGINS = [origin.strip() for origin in ALLOWED_ORIGINS]

print(f"\n📋 CORS Allowed Origins: {ALLOWED_ORIGINS}\n")

app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allow_headers=["Content-Type", "Authorization"],
    max_age=600,
)

# ==================== HELPER FUNCTIONS ====================

def get_cache_key(prefix: str, identifier: str) -> str:
    """Generate Redis cache key"""
    return f"ml:recommend:{prefix}:{identifier}"

def get_from_cache(key: str) -> Optional[dict]:
    """Get data from Redis cache"""
    if not redis_client:
        return None
    
    try:
        data = redis_client.get(key)
        if data:
            return json.loads(data)
    except Exception as e:
        print(f"Cache read error: {e}")
    
    return None

def set_to_cache(key: str, data: dict, ttl: int = 3600):
    """Set data to Redis cache with TTL"""
    if not redis_client:
        return
    
    try:
        redis_client.setex(key, ttl, json.dumps(data))
    except Exception as e:
        print(f"Cache write error: {e}")

def _convert_to_response(recommendations: List[dict]) -> List[RecommendationResponse]:
    """Convert model recommendations to API responses"""
    responses = []
    for rec in recommendations:
        coords = rec.get('coordinates', (0, 0))
        responses.append(
            RecommendationResponse(
                rentalId=rec['rentalId'],
                score=rec.get('score', 0),
                method=rec.get('method', 'unknown'),
                coordinates=Coordinates(
                    longitude=float(coords[0]),
                    latitude=float(coords[1])
                ) if coords[0] != 0 or coords[1] != 0 else None,
                locationBonus=rec.get('locationBonus', 1.0),
                finalScore=rec.get('finalScore', rec.get('score', 0)),
                distance_km=rec.get('distance_km')
            )
        )
    return responses

# ==================== API ENDPOINTS ====================

@app.get("/")
async def root():
    """Root endpoint"""
    return {
        "service": "Rental Recommendation API with Geographic Features",
        "version": "2.0.0",
        "status": "running",
        "features": [
            "Collaborative Filtering",
            "Content-Based Filtering",
            "Geographic Proximity Analysis",
            "Location-Aware Recommendations"
        ],
        "model_loaded": model is not None,
        "redis_connected": redis_client is not None
    }

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "model_loaded": model is not None,
        "redis_connected": redis_client is not None,
        "timestamp": datetime.now().isoformat()
    }

@app.post("/recommend/personalized", response_model=RecommendationsResult)
async def get_personalized_recommendations(request: RecommendRequest):
    """
    🌍 Gợi ý cá nhân hóa với xem xét vị trí địa lý (Collaborative Filtering)
    
    **Features:**
    - Dựa trên user behavior & similar users
    - Apply geographic proximity bonus (gần user → điểm cao)
    - Show coordinates cho frontend hiển thị trên bản đồ
    - Tính khoảng cách từ user centroid
    
    **Request:**
    - userId: ID của user
    - n_recommendations: 1-50 gợi ý
    - use_location: áp dụng geographic filter (default: true)
    - exclude_items: rental IDs cần loại trừ
    
    **Response:**
    - coordinates: [longitude, latitude] để hiển thị marker
    - locationBonus: 1.0 = no bonus, > 1.0 = nearby bonus
    - finalScore: score đã apply location bonus
    - distance_km: khoảng cách từ user centroid
    """
    
    if model is None:
        raise HTTPException(status_code=503, detail="Model not loaded. Train the model first.")
    
    # Check cache
    cache_key = get_cache_key("personalized", request.userId)
    cached_data = get_from_cache(cache_key)
    
    if cached_data:
        print(f"✅ Cache HIT for user {request.userId}")
        return RecommendationsResult(
            success=True,
            userId=request.userId,
            recommendations=[RecommendationResponse(**r) for r in cached_data['recommendations']],
            count=len(cached_data['recommendations']),
            cached=True,
            generated_at=cached_data['generated_at']
        )
    
    # Generate recommendations
    print(f"🔍 Generating personalized recommendations for user {request.userId}...")
    print(f"   Use location: {request.use_location}")
    
    try:
        recommendations = model.recommend_for_user(
            user_id=request.userId,
            n_recommendations=request.n_recommendations,
            exclude_items=request.exclude_items,
            use_location=request.use_location
        )
        
        # Convert to API response format
        response_recs = _convert_to_response(recommendations)
        
        # Cache data
        result = {
            'recommendations': [r.dict() for r in response_recs],
            'generated_at': datetime.now().isoformat()
        }
        set_to_cache(cache_key, result, ttl=3600)
        
        # Get model info
        model_info = {
            "method": "collaborative_filtering_with_location",
            "user_count": len(model.user_encoder.classes_),
            "rental_count": len(model.item_encoder.classes_),
            "user_location_known": request.userId in model.user_locations
        }
        
        if request.userId in model.user_locations:
            loc = model.user_locations[request.userId]
            model_info["user_centroid"] = {
                "longitude": float(loc[0]),
                "latitude": float(loc[1])
            }
        
        return RecommendationsResult(
            success=True,
            userId=request.userId,
            recommendations=response_recs,
            count=len(response_recs),
            cached=False,
            generated_at=result['generated_at'],
            model_info=model_info
        )
        
    except Exception as e:
        print(f"❌ Error generating recommendations: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/recommend/similar", response_model=RecommendationsResult)
async def get_similar_items(request: SimilarItemsRequest):
    """
    🏘️ Tìm các bài đăng tương tự (Content-Based) + vị trí gần nhau
    
    **Features:**
    - Dựa trên content similarity (price, type, amenities)
    - Geographic proximity bonus (gần rental gốc → điểm cao)
    - Show distance_km so với rental reference
    - Perfect cho "Show similar properties nearby"
    """
    
    if model is None:
        raise HTTPException(status_code=503, detail="Model not loaded. Train the model first.")
    
    cache_key = get_cache_key("similar", request.rentalId)
    cached_data = get_from_cache(cache_key)
    
    if cached_data:
        print(f"✅ Cache HIT for rental {request.rentalId}")
        return RecommendationsResult(
            success=True,
            recommendations=[RecommendationResponse(**r) for r in cached_data['recommendations']],
            count=len(cached_data['recommendations']),
            cached=True,
            generated_at=cached_data['generated_at']
        )
    
    print(f"🔍 Finding similar items for rental {request.rentalId}...")
    print(f"   Use location proximity: {request.use_location}")
    
    try:
        recommendations = model.recommend_similar_items(
            item_id=request.rentalId,
            n_recommendations=request.n_recommendations,
            use_location=request.use_location
        )
        
        response_recs = _convert_to_response(recommendations)
        
        result = {
            'recommendations': [r.dict() for r in response_recs],
            'generated_at': datetime.now().isoformat()
        }
        set_to_cache(cache_key, result, ttl=21600)
        
        return RecommendationsResult(
            success=True,
            recommendations=response_recs,
            count=len(response_recs),
            cached=False,
            generated_at=result['generated_at']
        )
        
    except Exception as e:
        print(f"❌ Error finding similar items: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/recommend/popular", response_model=RecommendationsResult)
async def get_popular_items(request: PopularItemsRequest):
    """
    ⭐ Lấy các bài đăng phổ biến nhất (Popularity-Based)
    
    **Features:**
    - Dựa trên interaction scores (views, favorites, contacts)
    - Good for cold-start & new users
    - Include coordinates cho map display
    """
    
    if model is None:
        raise HTTPException(status_code=503, detail="Model not loaded. Train the model first.")
    
    cache_key = get_cache_key("popular", "all")
    cached_data = get_from_cache(cache_key)
    
    if cached_data:
        print(f"✅ Cache HIT for popular items")
        return RecommendationsResult(
            success=True,
            recommendations=[RecommendationResponse(**r) for r in cached_data['recommendations']],
            count=len(cached_data['recommendations']),
            cached=True,
            generated_at=cached_data['generated_at']
        )
    
    print(f"🔍 Getting popular items...")
    
    try:
        recommendations = model.get_popular_items(
            n_recommendations=request.n_recommendations,
            exclude_items=request.exclude_items
        )
        
        response_recs = _convert_to_response(recommendations)
        
        result = {
            'recommendations': [r.dict() for r in response_recs],
            'generated_at': datetime.now().isoformat()
        }
        set_to_cache(cache_key, result, ttl=1800)
        
        return RecommendationsResult(
            success=True,
            recommendations=response_recs,
            count=len(response_recs),
            cached=False,
            generated_at=result['generated_at']
        )
        
    except Exception as e:
        print(f"❌ Error getting popular items: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/cache/clear")
async def clear_cache(pattern: str = "ml:recommend:*"):
    """Clear Redis cache"""
    
    if not redis_client:
        raise HTTPException(status_code=503, detail="Redis not connected")
    
    try:
        keys = redis_client.keys(pattern)
        if keys:
            redis_client.delete(*keys)
        
        return {
            "success": True,
            "message": f"Deleted {len(keys)} cache keys",
            "pattern": pattern
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/model/info")
async def get_model_info():
    """Get information about the loaded model - including geographic data"""
    
    if model is None:
        raise HTTPException(status_code=503, detail="Model not loaded")
    
    return {
        "success": True,
        "info": {
            "n_users": len(model.user_encoder.classes_),
            "n_items": len(model.item_encoder.classes_),
            "n_interactions": model.user_item_matrix.nnz if model.user_item_matrix else 0,
            "matrix_sparsity": f"{100 * (1 - model.user_item_matrix.nnz / (len(model.user_encoder.classes_) * len(model.item_encoder.classes_))):.2f}%" if model.user_item_matrix else "N/A",
            "n_popular_items": len(model.popularity_scores),
            "geographic_features": {
                "rental_coordinates_stored": len(model.rental_coordinates),
                "user_locations_calculated": len(model.user_locations),
                "geographic_recommendations_enabled": True
            }
        }
    }

@app.get("/coordinates/stats")
async def get_coordinates_stats():
    """Get statistics about coordinates coverage in the model"""
    
    if model is None:
        raise HTTPException(status_code=503, detail="Model not loaded")
    
    # Count valid coordinates
    valid_rental_coords = len([
        (k, v) for k, v in model.rental_coordinates.items()
        if v[0] != 0 and v[1] != 0
    ])
    
    return {
        "success": True,
        "stats": {
            "total_rentals": len(model.item_encoder.classes_),
            "rentals_with_coordinates": len(model.rental_coordinates),
            "rentals_with_valid_coordinates": valid_rental_coords,
            "coverage_percentage": f"{100 * valid_rental_coords / len(model.item_encoder.classes_):.2f}%",
            "users_with_location_calculated": len(model.user_locations),
            "geographic_features_ready": valid_rental_coords > len(model.item_encoder.classes_) * 0.8
        }
    }

# ==================== RUN SERVER ====================

if __name__ == "__main__":
    import uvicorn
    
    port = int(os.getenv('PORT', 8001))
    
    print("\n" + "="*70)
    print("🚀 STARTING FASTAPI SERVER WITH GEOGRAPHIC FEATURES")
    print("="*70)
    print(f"   URL: http://localhost:{port}")
    print(f"   Docs: http://localhost:{port}/docs")
    print(f"   ReDoc: http://localhost:{port}/redoc")
    print("="*70 + "\n")
    
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=port,
        reload=True,
        log_level="info"
    )