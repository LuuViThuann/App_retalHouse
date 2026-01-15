import os
import sys
from typing import List, Optional, Tuple, Dict, Any
from contextlib import asynccontextmanager
from fastapi import FastAPI, HTTPException, BackgroundTasks, Query 
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
import redis
import json
from datetime import datetime, timedelta
from dotenv import load_dotenv
from pydantic import ConfigDict
from functools import wraps
import hashlib

# Add parent directory to path
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from training.train_model import RecommendationModel

load_dotenv()


# ==================== PYDANTIC MODELS ====================

class ContextData(BaseModel):
    """Context khi user tương tác"""
    map_center: Optional[tuple] = Field(None, description="Tâm map (lon, lat)")
    zoom_level: Optional[int] = Field(None, description="Zoom level")
    search_radius: Optional[int] = Field(10, description="Bán kính tìm kiếm (km)")
    time_of_day: Optional[str] = Field("morning", description="morning|afternoon|evening|night")
    weekday: Optional[str] = Field(None, description="Thứ trong tuần")
    device_type: Optional[str] = Field("mobile", description="mobile|desktop|tablet")
    impressions: Optional[List[str]] = Field([], description="Rentals đã hiển thị")
    scroll_depth: Optional[float] = Field(0.5, description="0.0 - 1.0")

class PersonalizedRecommendRequest(BaseModel):
    """Request gợi ý cá nhân hóa"""
    userId: str = Field(..., description="User ID")
    n_recommendations: int = Field(default=10, ge=1, le=50)
    exclude_items: Optional[List[str]] = Field(None)
    use_location: bool = Field(default=True)
    radius_km: int = Field(default=20)
    context: Optional[ContextData] = None

class ExplanationItem(BaseModel):
    """Chi tiết giải thích gợi ý"""
    reason: str
    weight: Optional[float] = Field(None, description="Trọng số (0-1)")
    detail: Optional[str] = None

class PersonalizedRecommendationResponse(BaseModel):
    """Single personalized recommendation"""
    rentalId: str
    score: float
    locationBonus: Optional[float] = 1.0
    preferenceBonus: Optional[float] = 1.0
    timeBonus: Optional[float] = 1.0
    finalScore: float
    method: str
    coordinates: Optional[Dict[str, float]] = None
    distance_km: Optional[float] = None
    explanation: Optional[Dict[str, Any]] = None  # 🔥 WHY gợi ý bài này?
    confidence: Optional[float] = 0.5  # Độ tin cậy (0-1)
    markers_priority: Optional[int] = None  # Thứ tự ưu tiên trên map

class UserPreferencesResponse(BaseModel):
    """Thông tin preferences của user"""
    userId: str
    total_interactions: int
    property_type_distribution: Dict[str, int]
    price_range: Dict[str, float]
    top_locations: Dict[str, int]
    interaction_types: Dict[str, int]
    avg_search_radius: Optional[float] = None

class PersonalizedResultResponse(BaseModel):
    """Response với recommendations + metadata"""
    success: bool
    userId: str
    recommendations: List[PersonalizedRecommendationResponse]
    count: int
    cached: bool = False
    generated_at: str
    user_preferences: Optional[UserPreferencesResponse] = None
    personalization_info: Optional[Dict[str, Any]] = None

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
    model_config = ConfigDict(protected_namespaces=())
    
    success: bool
    userId: Optional[str] = None
    recommendations: List[RecommendationResponse]
    count: int
    cached: bool = False
    generated_at: str
    model_info: Optional[dict] = Field(None, description="Model metadata")  # 🔥 Đổi từ model_info thành info

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

def cache_response(ttl: int = 3600):
    """Decorator để cache API responses"""
    def decorator(func):
        @wraps(func)
        async def wrapper(*args, **kwargs):
            # Tạo cache key từ function name + parameters
            cache_key = f"{func.__name__}:{hashlib.sha256(str(kwargs).encode()).hexdigest()}"
            
            # Check cache
            cached = get_from_cache(cache_key)
            if cached:
                print(f"✅ Cache HIT: {cache_key}")
                return cached
            
            # Execute function
            result = await func(*args, **kwargs)
            
            # Save cache
            set_to_cache(cache_key, result, ttl)
            return result
        return wrapper
    return decorator

@app.post("/recommend/batch")
async def batch_recommendations(requests: List[PersonalizedRecommendRequest]):
    """Process nhiều user cùng lúc"""
    recommendations = []
    
    # Process parallel
    import asyncio
    tasks = [
        model.recommend_for_user(req.userId, req.n_recommendations)
        for req in requests
    ]
    
    results = await asyncio.gather(*tasks)
    return results
    
@app.post("/recommend/personalized")
@cache_response(ttl=1800)

@app.post("/recommend/personalized", response_model=PersonalizedResultResponse)
async def get_personalized_recommendations(request: PersonalizedRecommendRequest):
    """
    🎯 Gợi ý cá nhân hóa với Explainable AI
    
    **Features:**
    - Dựa trên user behavior & similar users
    - Cá nhân hóa theo preferences
    - Giải thích được (WHY gợi ý bài này?)
    - Marker priority cho map
    - Confidence score
    
    **Request:**
    - userId: ID của user
    - context: Map center, zoom, device, thời gian, etc.
    
    **Response:**
    - explanation: Lý do gợi ý (Collaborative, Location, Preference)
    - confidence: Độ tin cậy (0-1)
    - markers_priority: Thứ tự hiển thị trên map
    """
    
    if model is None:
        raise HTTPException(status_code=503, detail="Model not loaded")
    
    # Check cache
    cache_key = get_cache_key("personalized", request.userId)
    cached_data = get_from_cache(cache_key)
    
    if cached_data:
        print(f"✅ Cache HIT for user {request.userId}")
        return PersonalizedResultResponse(
            success=True,
            userId=request.userId,
            recommendations=[PersonalizedRecommendationResponse(**r) for r in cached_data['recommendations']],
            count=len(cached_data['recommendations']),
            cached=True,
            generated_at=cached_data['generated_at'],
            user_preferences=cached_data.get('user_preferences')
        )
    
    print(f"🎯 Generating PERSONALIZED recommendations for user {request.userId}...")
    print(f"   Context: {request.context}")
    
    try:
        # Convert Pydantic model to dict for model.recommend_for_user
        context = request.context.dict() if request.context else {}
        
        recommendations = model.recommend_for_user(
            user_id=request.userId,
            n_recommendations=request.n_recommendations,
            exclude_items=request.exclude_items,
            use_location=request.use_location,
            radius_km=request.radius_km,
            context=context  # 🔥 THÊM context
        )
        
        # Convert to API response format
        response_recs = []
        for i, rec in enumerate(recommendations, 1):
            rec_dict = rec.copy()
            
            # Add marker priority (rank)
            rec_dict['markers_priority'] = i
            
            # Extract coordinates
            coords = rec_dict.get('coordinates', (0, 0))
            rec_dict['coordinates'] = {
                'longitude': float(coords[0]),
                'latitude': float(coords[1])
            }
            
            # Convert distance
            if 'distance_km' in rec_dict:
                rec_dict['distance_km'] = float(rec_dict['distance_km']) if rec_dict['distance_km'] else None
            
            response_recs.append(PersonalizedRecommendationResponse(**rec_dict))
        
        # Get user preferences
        user_prefs = model.get_user_preferences(request.userId)
        user_prefs_response = None
        
        if user_prefs:
            user_prefs_response = UserPreferencesResponse(
                userId=request.userId,
                total_interactions=user_prefs['total_interactions'],
                property_type_distribution=user_prefs['property_type_distribution'],
                price_range=user_prefs['price_range'],
                top_locations=user_prefs['top_locations'],
                interaction_types=user_prefs['interaction_types'],
            )
        
        # Cache data
        result = {
            'recommendations': [r.dict() for r in response_recs],
            'generated_at': datetime.now().isoformat(),
            'user_preferences': user_prefs_response.dict() if user_prefs_response else None
        }
        set_to_cache(cache_key, result, ttl=3600)
        
        # Personalization info
        personalization_info = {
            'method': 'collaborative_filtering_with_personalization',
            'context_applied': bool(context),
            'radius_km': request.radius_km,
            'user_location_known': request.userId in model.user_locations,
            'confidence_avg': sum(r.confidence or 0 for r in response_recs) / len(response_recs) if response_recs else 0,
        }
        
        return PersonalizedResultResponse(
            success=True,
            userId=request.userId,
            recommendations=response_recs,
            count=len(response_recs),
            cached=False,
            generated_at=result['generated_at'],
            user_preferences=user_prefs_response,
            personalization_info=personalization_info
        )
        
    except Exception as e:
        print(f"❌ Error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

# ==================== API ENDPOINT: User Preferences ====================
@app.get("/user-preferences/{userId}")
async def get_user_preferences(userId: str):
    """
    👤 Lấy thông tin preferences của user
    
    **Response:**
    - property_type_distribution: Loại BĐS user thích
    - price_range: Tầm giá user quan tâm
    - top_locations: Các khu vực yêu thích
    - avg_search_radius: Bán kính tìm kiếm trung bình
    """
    
    if model is None:
        raise HTTPException(status_code=503, detail="Model not loaded")
    
    try:
        prefs = model.get_user_preferences(userId)
        
        if not prefs:
            return {
                'success': False,
                'message': f'No preferences found for user {userId}',
                'userId': userId
            }
        
        return {
            'success': True,
            'userId': userId,
            'preferences': prefs,
            'timestamp': datetime.now().isoformat()
        }
    
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ==================== API ENDPOINT: Explain Recommendation ====================

@app.post("/recommend/explain")
async def explain_recommendation(
    userId: str = Query(...),
    rentalId: str = Query(...)
):
    """
    🤔 Giải thích CHI TIẾT tại sao bài đăng này được gợi ý
    
    **Response:**
    - collaborative_score: Điểm từ collaborative filtering
    - location_analysis: Phân tích vị trí
    - preference_match: Khớp với preferences của user
    - final_explanation: Giải thích tổng hợp
    """
    
    if model is None:
        raise HTTPException(status_code=503, detail="Model not loaded")
    
    try:
        # Generate recommendation
        recs = model.recommend_for_user(userId, n_recommendations=100)
        
        # Find the rental
        matched_rec = next((r for r in recs if r['rentalId'] == rentalId), None)
        
        if not matched_rec:
            return {
                'success': False,
                'message': f'Rental {rentalId} not in recommendations',
                'userId': userId,
                'rentalId': rentalId
            }
        
        # Get user preferences
        user_prefs = model.get_user_preferences(userId)
        
        # Get rental info
        if hasattr(model, 'item_features') and rentalId in model.item_features:
            rental_features = model.item_features[rentalId]
        else:
            rental_features = {}
        
        explanation = {
            'userId': userId,
            'rentalId': rentalId,
            'reasons': matched_rec.get('explanation', {}),
            'scores': {
                'collaborative_score': matched_rec['score'],
                'location_bonus': matched_rec.get('locationBonus', 1.0),
                'preference_bonus': matched_rec.get('preferenceBonus', 1.0),
                'time_bonus': matched_rec.get('timeBonus', 1.0),
                'final_score': matched_rec['finalScore'],
                'confidence': matched_rec.get('confidence', 0.5),
            },
            'user_context': {
                'total_interactions': user_prefs['total_interactions'] if user_prefs else 0,
                'top_property_types': list(user_prefs['property_type_distribution'].keys())[:3] if user_prefs else [],
                'price_preference': user_prefs['price_range'] if user_prefs else {},
            },
            'rental_features': {
                'price': rental_features.get('price', 0),
                'property_type': rental_features.get('propertyType', 'unknown'),
                'location': rental_features.get('location_text', 'unknown'),
                'distance_km': matched_rec.get('distance_km'),
            },
            'summary': _generate_explanation_summary(matched_rec, user_prefs)
        }
        
        return {
            'success': True,
            'explanation': explanation
        }
    
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# ==================== HELPER: Generate Explanation Summary ====================

def _generate_explanation_summary(recommendation: dict, user_prefs: dict = None) -> str:
    """Tạo giải thích dạng text"""
    
    reasons = []
    
    # Collaborative reason
    if 'collaborative_filtering' in recommendation.get('explanation', {}):
        reasons.append("💬 Người dùng tương tự đã xem")
    
    # Location reason
    if recommendation.get('explanation', {}).get('location'):
        reasons.append(f"📍 {recommendation['explanation']['location']}")
    
    # Preference reason
    prefs = recommendation.get('explanation', {}).get('preference', [])
    if prefs:
        reasons.append(f"✨ {'; '.join(prefs)}")
    
    # Interaction reason
    interaction = recommendation.get('explanation', {}).get('interaction_count')
    if interaction:
        reasons.append(f"👁️ {interaction}")
    
    return " • ".join(reasons) if reasons else "Bài đăng phù hợp cho bạn"        
    
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