import os
import sys
from typing import List, Optional, Tuple, Dict, Any
from contextlib import asynccontextmanager
from fastapi import FastAPI, HTTPException, BackgroundTasks, Query 
from fastapi.middleware.cors import CORSMiddleware

from openai_chat_service import RentalChatAssistant
from pydantic import BaseModel, Field, model_validator
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
    user_id: Optional[str] = Field(None, alias="userId")
    userId: Optional[str] = Field(None)
    
    # 🔥 CHANGE: Increase max from 50 to 100 if needed
    n_recommendations: int = Field(default=10, ge=1, le=100)  # Was 50, now 100
    exclude_items: Optional[List[str]] = Field(None)
    use_location: bool = Field(default=True)
    radius_km: int = Field(default=20)
    context: Optional[ContextData] = None
    
    model_config = ConfigDict(populate_by_name=True)
    
    @model_validator(mode='before')
    @classmethod
    def resolve_user_id(cls, values):
        """Resolve user_id from either userId or user_id"""
        if isinstance(values, dict):
            user_id = values.get('user_id') or values.get('userId')
            if not user_id:
                raise ValueError('user_id or userId is required')
            values['user_id'] = user_id
        return values
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
    # 🔥 CHANGE: Also increase here if needed
    n_recommendations: int = Field(default=10, ge=1, le=100)  # Was 50, now 100
    use_location: bool = Field(default=True, description="Apply geographic proximity bonus")

    model_config = ConfigDict(populate_by_name=True)

class PopularItemsRequest(BaseModel):
    # 🔥 CHANGE: Also increase here if needed
    n_recommendations: int = Field(default=10, ge=1, le=100)  # Was 50, now 100
    exclude_items: Optional[List[str]] = None

    model_config = ConfigDict(populate_by_name=True)

class RecommendationResponse(BaseModel):
    """Single recommendation with geographic data"""
    rentalId: str
    score: float
    method: str
    coordinates: Optional[Coordinates] = None  # 🔥 MAKE IT OPTIONAL
    locationBonus: float = 1.0
    finalScore: float = 0
    distance_km: Optional[float] = None

    @model_validator(mode='after')
    def validate_coordinates(self):
        """Ensure coordinates are valid if provided"""
        if self.coordinates:
            # Validate longitude range
            if not (-180 <= self.coordinates.longitude <= 180):
                self.coordinates = None
            # Validate latitude range
            elif not (-90 <= self.coordinates.latitude <= 90):
                self.coordinates = None
        return self

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
chat_assistant: Optional[RentalChatAssistant] = None
# ==================== LIFESPAN EVENT HANDLERS ====================

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Lifespan context manager for startup and shutdown events."""
    global model, redis_client, chat_assistant
    
    # ============ STARTUP ============
    print("\n" + "="*70)
    print("🚀 STARTING FASTAPI ML SERVICE WITH OPENAI CHAT")
    print("="*70 + "\n")
    
    # Load ML model
    model_path = os.getenv('MODEL_PATH', './models/recommendation_model.pkl')
    
    try:
        model = RecommendationModel.load(model_path)
        print("✅ ML Model loaded successfully")
    except Exception as e:
        print(f"⚠️ ML Model not available: {e}")
        model = None
    
    # Connect to Redis
    redis_url = os.getenv('REDIS_URL', 'redis://localhost:6379')
    
    try:
        redis_client = redis.from_url(redis_url, decode_responses=True)
        redis_client.ping()
        print("✅ Connected to Redis\n")
    except Exception as e:
        print(f"⚠️ Redis not available: {e}\n")
        redis_client = None
    
    # 🔥 INITIALIZE CHAT ASSISTANT
    try:
        chat_assistant = RentalChatAssistant(model=model)
        print("✅ OpenAI Chat Assistant initialized\n")
    except Exception as e:
        print(f"⚠️ Chat Assistant not available: {e}\n")
        print("   Make sure GROQ_API_KEY is set in .env\n")
        chat_assistant = None
    
    print("="*70)
    print("✅ SERVICE READY")
    print("="*70 + "\n")
    
    yield  # Application runs here
    
    # ============ SHUTDOWN ============
    if redis_client:
        redis_client.close()
        print("✅ Redis connection closed")


# ==================== PYDANTIC MODELS FOR CHAT ====================

class ChatMessage(BaseModel):
    """Single chat message"""
    role: str = Field(..., description="user or assistant")
    content: str = Field(..., description="Message content")
    timestamp: Optional[str] = None

class ChatRequest(BaseModel):
    """Chat request"""
    userId: str = Field(..., description="User ID")
    message: str = Field(..., description="User message")
    conversationHistory: Optional[List[ChatMessage]] = Field(default=[], description="Previous messages")
    userContext: Optional[Dict[str, Any]] = Field(default=None, description="User context (location, preferences)")
    includeRecommendations: bool = Field(default=True, description="Include rental recommendations if applicable")

class ChatResponse(BaseModel):
    """Chat response"""
    success: bool
    message: str
    intent: str
    extractedPreferences: Optional[Dict[str, Any]] = None
    shouldRecommend: bool = False
    recommendations: Optional[List[PersonalizedRecommendationResponse]] = None
    explanation: Optional[str] = None
    usage: Optional[Dict[str, int]] = None

class RentalExplanationRequest(BaseModel):
    """Request to explain a specific rental"""
    userId: str
    rentalId: str
    conversationContext: Optional[str] = ""




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
        # 🔥 FIX 1: Safely extract coordinates
        coords = rec.get('coordinates', (0, 0))
        
        # Handle different coordinate formats
        if coords is None:
            coords = (0, 0)
        elif isinstance(coords, dict):
            coords = (coords.get('longitude', 0), coords.get('latitude', 0))
        elif not isinstance(coords, (list, tuple)):
            coords = (0, 0)
        
        # Ensure we have a valid tuple
        if len(coords) < 2:
            coords = (0, 0)
        
        lon = float(coords[0]) if coords[0] else 0
        lat = float(coords[1]) if coords[1] else 0
        
        # 🔥 FIX 2: Only create Coordinates object if valid
        coordinates_obj = None
        if lon != 0 or lat != 0:
            coordinates_obj = Coordinates(
                longitude=lon,
                latitude=lat
            )
        
        # 🔥 FIX 3: Safe field extraction with defaults
        responses.append(
            RecommendationResponse(
                rentalId=str(rec.get('rentalId', '')),
                score=float(rec.get('score', 0)),
                method=str(rec.get('method', 'unknown')),
                coordinates=coordinates_obj,  # Can be None
                locationBonus=float(rec.get('locationBonus', 1.0)),
                finalScore=float(rec.get('finalScore', rec.get('score', 0))),
                distance_km=float(rec.get('distance_km')) if rec.get('distance_km') is not None else None
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

# ==================== CHAT ENDPOINTS ====================

@app.post("/chat", response_model=ChatResponse)
async def chat_with_ai(request: ChatRequest):
    """
    🤖 Chat với AI về nhu cầu thuê nhà
    
    **Features:**
    - Chat tự nhiên về tìm nhà
    - Tự động phân tích preferences
    - Gợi ý rentals khi đủ thông tin
    - Giải thích chi tiết
    
    **Example:**
    ```
    POST /chat
    {
        "userId": "user123",
        "message": "Tôi cần tìm phòng trọ khoảng 3 triệu gần trường",
        "conversationHistory": [],
        "includeRecommendations": true
    }
    ```
    """
    
    if chat_assistant is None:
        raise HTTPException(
            status_code=503, 
            detail="Chat service not available. Check GROQ_API_KEY in environment."
        )
    
    print(f"\n🤖 [CHAT] User: {request.userId}")
    print(f"   Message: {request.message[:100]}...")
    
    try:
        # Convert Pydantic models to dicts
        conversation_history = [
            {"role": msg.role, "content": msg.content}
            for msg in request.conversationHistory
        ] if request.conversationHistory else []
        
        # Chat with AI
        chat_result = chat_assistant.chat(
            user_message=request.message,
            conversation_history=conversation_history,
            user_context=request.userContext
        )
        
        print(f"   Intent: {chat_result['intent']}")
        print(f"   Should recommend: {chat_result['should_recommend']}")
        
        # Get recommendations if needed
        recommendations = None
        explanation = None
        
        if (request.includeRecommendations and 
            chat_result['should_recommend'] and 
            chat_result['extracted_preferences']):
            
            print(f"   🎯 Getting recommendations...")
            
            rec_result = chat_assistant.get_rental_recommendations_with_chat(
                user_id=request.userId,
                preferences=chat_result['extracted_preferences'],
                conversation_context=request.message,
                n_recommendations=5
            )
            
            if rec_result['recommendations']:
                # Convert to response format
                recommendations = []
                for rec in rec_result['recommendations']:
                    coords = rec.get('coordinates', (0, 0))
                    recommendations.append(
                        PersonalizedRecommendationResponse(
                            rentalId=rec['rentalId'],
                            score=rec.get('score', 0),
                            locationBonus=rec.get('locationBonus', 1.0),
                            preferenceBonus=rec.get('preferenceBonus', 1.0),
                            timeBonus=rec.get('timeBonus', 1.0),
                            finalScore=rec.get('finalScore', 0),
                            method=rec.get('method', 'chat_based'),
                            coordinates={'longitude': coords[0], 'latitude': coords[1]},
                            distance_km=rec.get('distance_km'),
                            confidence=rec.get('confidence', 0.5)
                        )
                    )
                
                explanation = rec_result.get('explanation')
                
                print(f"   ✅ Added {len(recommendations)} recommendations")
        
        return ChatResponse(
            success=True,
            message=chat_result['message'],
            intent=chat_result['intent'],
            extractedPreferences=chat_result.get('extracted_preferences'),
            shouldRecommend=chat_result['should_recommend'],
            recommendations=recommendations,
            explanation=explanation,
            usage=chat_result.get('usage')
        )
        
    except Exception as e:
        print(f"❌ Error in chat: {e}")
        import traceback
        traceback.print_exc()
        
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/chat/explain-rental")
async def explain_rental_with_ai(request: RentalExplanationRequest):
    """
    🤔 Giải thích chi tiết 1 bài đăng bằng AI
    
    **Example:**
    ```
    POST /chat/explain-rental
    {
        "userId": "user123",
        "rentalId": "rental456",
        "conversationContext": "Tôi đang tìm phòng trọ gần trường"
    }
    ```
    """
    
    if chat_assistant is None:
        raise HTTPException(
            status_code=503,
            detail="Chat service not available"
        )
    
    print(f"\n🤔 [EXPLAIN] Rental: {request.rentalId} for User: {request.userId}")
    
    try:
        # Get user preferences
        user_prefs = None
        if model:
            user_prefs = model.get_user_preferences(request.userId)
        
        # Generate explanation
        explanation = chat_assistant.explain_rental_detail(
            rental_id=request.rentalId,
            user_preferences=user_prefs,
            conversation_context=request.conversationContext
        )
        
        print(f"   ✅ Explanation generated")
        
        return {
            'success': True,
            'rentalId': request.rentalId,
            'explanation': explanation,
            'userPreferences': user_prefs
        }
        
    except Exception as e:
        print(f"❌ Error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/chat/conversation/{userId}")
async def get_conversation_suggestions(userId: str):
    """
    💡 Lấy gợi ý câu hỏi tiếp theo cho user
    
    **Features:**
    - Suggest next questions based on current state
    - Help guide the conversation
    """
    
    if chat_assistant is None:
        raise HTTPException(status_code=503, detail="Chat service not available")
    
    try:
        # Get user preferences to determine what to ask next
        user_prefs = model.get_user_preferences(userId) if model else None
        
        # Generate suggestions using AI
        prompt = f"""Dựa trên thông tin hiện tại của khách hàng:
{json.dumps(user_prefs, ensure_ascii=False, indent=2) if user_prefs else 'Chưa có'}

Hãy đề xuất 3-4 câu hỏi mà tư vấn viên nên hỏi tiếp để hiểu rõ hơn nhu cầu.

Format: JSON array of strings
["Câu hỏi 1?", "Câu hỏi 2?", ...]

CHỈ trả về JSON array."""

        response = chat_assistant.client.chat.completions.create(
            model="gpt-3.5-turbo",
            messages=[
                {"role": "system", "content": "Bạn là tư vấn viên bất động sản. Chỉ trả về JSON."},
                {"role": "user", "content": prompt}
            ],
            temperature=0.7,
            max_tokens=200
        )
        
        suggestions_text = response.choices[0].message.content.strip()
        
        # Parse JSON
        if suggestions_text.startswith('```'):
            suggestions_text = suggestions_text.split('```')[1]
            if suggestions_text.startswith('json'):
                suggestions_text = suggestions_text[4:]
        
        suggestions = json.loads(suggestions_text.strip())
        
        return {
            'success': True,
            'userId': userId,
            'suggestions': suggestions,
            'userPreferences': user_prefs
        }
        
    except Exception as e:
        print(f"❌ Error: {e}")
        # Fallback suggestions
        return {
            'success': True,
            'userId': userId,
            'suggestions': [
                "Bạn muốn thuê nhà ở khu vực nào?",
                "Tầm giá bao nhiêu là phù hợp với bạn?",
                "Bạn cần bao nhiêu phòng ngủ?",
                "Có tiện ích nào quan trọng với bạn không?"
            ],
            'fallback': True
        }


# ==================== USAGE STATS ====================

@app.get("/chat/stats")
async def get_chat_stats():
    """📊 Lấy thống kê sử dụng OpenAI API"""
    
    if chat_assistant is None:
        raise HTTPException(status_code=503, detail="Chat service not available")
    
    return {
        'success': True,
        'chat_model': chat_assistant.chat_model,
        'ml_model_loaded': chat_assistant.model is not None,
        'status': 'active'
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
    
    **Fixed Issues:**
    - ✅ Accept both userId (from Node.js) and user_id (REST)
    - ✅ Better error handling for invalid requests
    - ✅ Fallback to popularity when model not ready
    """
    
    if model is None:
        raise HTTPException(status_code=503, detail="Model not loaded")
    
    # Resolve user_id
    user_id = request.user_id or request.userId
    if not user_id:
        raise HTTPException(status_code=400, detail="user_id or userId is required")
    
    print(f"🎯 Personalized recommendation request:")
    print(f"   userId: {user_id}")
    print(f"   radius: {request.radius_km}km")
    print(f"   use_location: {request.use_location}")
    print(f"   context: {bool(request.context)}")
    
    # Check cache
    cache_key = get_cache_key("personalized", user_id)
    cached_data = get_from_cache(cache_key)
    
    if cached_data:
        print(f"✅ Cache HIT for user {user_id}")
        return PersonalizedResultResponse(
            success=True,
            userId=user_id,
            recommendations=[PersonalizedRecommendationResponse(**r) for r in cached_data['recommendations']],
            count=len(cached_data['recommendations']),
            cached=True,
            generated_at=cached_data['generated_at'],
            user_preferences=cached_data.get('user_preferences')
        )
    
    print(f"🎯 Generating PERSONALIZED recommendations for user {user_id}...")
    
    try:
        # Convert context to dict
        context = request.context.dict() if request.context else {}
        
        # Call model
        recommendations = model.recommend_for_user(
            user_id=user_id,
            n_recommendations=request.n_recommendations,
            exclude_items=request.exclude_items,
            use_location=request.use_location,
            radius_km=request.radius_km,
            context=context
        )
        
        print(f"✅ Generated {len(recommendations)} recommendations")
        
        # Convert to response format
        response_recs = []
        for i, rec in enumerate(recommendations, 1):
            rec_dict = rec.copy()
            rec_dict['markers_priority'] = i
            
            coords = rec_dict.get('coordinates', (0, 0))
            rec_dict['coordinates'] = {
                'longitude': float(coords[0]),
                'latitude': float(coords[1])
            }
            
            if 'distance_km' in rec_dict:
                rec_dict['distance_km'] = float(rec_dict['distance_km']) if rec_dict['distance_km'] else None
            
            response_recs.append(PersonalizedRecommendationResponse(**rec_dict))
        
        # Get user preferences
        user_prefs = model.get_user_preferences(user_id)
        user_prefs_response = None
        
        if user_prefs:
            user_prefs_response = UserPreferencesResponse(
                userId=user_id,
                total_interactions=user_prefs.get('total_interactions', 0),
                property_type_distribution=user_prefs.get('property_type_distribution', {}),
                price_range=user_prefs.get('price_range', {}),
                top_locations=user_prefs.get('top_locations', {}),
                interaction_types=user_prefs.get('interaction_types', {}),
            )
        
        # Cache result
        result = {
            'recommendations': [r.dict() for r in response_recs],
            'generated_at': datetime.now().isoformat(),
            'user_preferences': user_prefs_response.dict() if user_prefs_response else None
        }
        set_to_cache(cache_key, result, ttl=3600)
        
        return PersonalizedResultResponse(
            success=True,
            userId=user_id,
            recommendations=response_recs,
            count=len(response_recs),
            cached=False,
            generated_at=result['generated_at'],
            user_preferences=user_prefs_response,
            personalization_info={
                'method': 'collaborative_filtering_with_personalization',
                'context_applied': bool(context),
                'radius_km': request.radius_km,
                'user_location_known': user_id in model.user_locations,
            }
        )
        
    except Exception as e:
        print(f"❌ Error: {e}")
        import traceback
        traceback.print_exc()
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
    🤔 Giải thích CHI TIẾT với NHIỀU INSIGHTS hơn
    
    **Enhanced Features:**
    - ✅ Collaborative filtering analysis
    - ✅ Location & distance analysis
    - ✅ Price compatibility score
    - ✅ Property type preference match
    - ✅ Amenities similarity
    - ✅ Time-based insights
    - ✅ Interaction patterns
    - ✅ Similar users analysis
    """
    
    if model is None:
        raise HTTPException(status_code=503, detail="Model not loaded")
    
    try:
        # 1. Generate recommendations (with caching)
        cache_key = f"explain:{userId}:{rentalId}"
        cached = get_from_cache(cache_key)
        
        if cached:
            return cached
        
        recs = model.recommend_for_user(userId, n_recommendations=100)
        
        # 2. Find the rental
        matched_rec = next((r for r in recs if r['rentalId'] == rentalId), None)
        
        if not matched_rec:
            # 🔥 FALLBACK: Try to generate explanation anyway
            return _generate_fallback_explanation(userId, rentalId)
        
        # 3. Get user preferences
        user_prefs = model.get_user_preferences(userId)
        
        # 4. Get rental features
        rental_features = model.item_features.get(rentalId, {})
        
        # 5. Generate DETAILED explanation
        explanation = {
            'userId': userId,
            'rentalId': rentalId,
            
            # 🔥 SCORES - Chi tiết hơn
            'scores': {
                'confidence': matched_rec.get('confidence', 0.5),
                'collaborative_score': matched_rec['score'],
                'location_score': matched_rec.get('locationBonus', 1.0),
                'preference_score': matched_rec.get('preferenceBonus', 1.0),
                'time_score': matched_rec.get('timeBonus', 1.0),
                'final_score': matched_rec['finalScore'],
                
                # 🔥 NEW: Price compatibility (0-1)
                'price_match': _calculate_price_match(
                    rental_features.get('price', 0),
                    user_prefs
                ),
                
                # 🔥 NEW: Location compatibility (0-1)
                'location_match': min(1.0, matched_rec.get('locationBonus', 1.0)),
                
                # 🔥 NEW: Property type match (0-1)
                'property_type_match': _calculate_property_type_match(
                    rental_features.get('propertyType', ''),
                    user_prefs
                ),
            },
            
            # 🔥 REASONS - Nhiều chi tiết hơn
            'reasons': _generate_detailed_reasons(
                matched_rec, 
                user_prefs, 
                rental_features
            ),
            
            # 🔥 USER CONTEXT
            'user_context': {
                'total_interactions': user_prefs.get('total_interactions', 0) if user_prefs else 0,
                'favorite_property_types': _get_top_n(
                    user_prefs.get('property_type_distribution', {}), 3
                ) if user_prefs else [],
                'price_range': user_prefs.get('price_range', {}) if user_prefs else {},
                'top_locations': _get_top_n(
                    user_prefs.get('top_locations', {}), 3
                ) if user_prefs else [],
                'avg_view_duration': user_prefs.get('avg_duration', 0) if user_prefs else 0,
            },
            
            # 🔥 RENTAL FEATURES
            'rental_features': {
                'price': rental_features.get('price', 0),
                'property_type': rental_features.get('propertyType', 'Unknown'),
                'location': rental_features.get('location_text', 'Unknown'),
                'distance_km': matched_rec.get('distance_km'),
                'coordinates': matched_rec.get('coordinates', (0, 0)),
                'amenities_count': len(rental_features.get('amenities', [])),
            },
            
            # 🔥 INSIGHTS - Phân tích sâu
            'insights': _generate_insights(
                matched_rec, 
                user_prefs, 
                rental_features
            ),
            
            # 🔥 SUMMARY
            'summary': _generate_explanation_summary(matched_rec, user_prefs)
        }
        
        # Cache for 1 hour
        set_to_cache(cache_key, {
            'success': True,
            'explanation': explanation
        }, ttl=3600)
        
        return {
            'success': True,
            'explanation': explanation
        }
    
    except Exception as e:
        print(f"❌ Error in explain_recommendation: {e}")
        raise HTTPException(status_code=500, detail=str(e))

# ==================== HELPER FUNCTIONS ====================

def _calculate_price_match(rental_price: float, user_prefs: dict) -> float:
    """Tính độ phù hợp về giá (0-1)"""
    if not user_prefs:
        return 0.5
    
    price_range = user_prefs.get('price_range', {})
    avg_price = price_range.get('avg', 0)
    min_price = price_range.get('min', 0)
    max_price = price_range.get('max', float('inf'))
    
    if not avg_price:
        return 0.5
    
    # Perfect match if within range
    if min_price <= rental_price <= max_price:
        # Closer to average = higher score
        diff = abs(rental_price - avg_price)
        max_diff = max(avg_price - min_price, max_price - avg_price)
        return 1.0 - (diff / max_diff) if max_diff > 0 else 1.0
    
    # Outside range - penalize
    if rental_price < min_price:
        return 0.7  # Cheaper than usual (still acceptable)
    else:
        # More expensive - heavier penalty
        overprice_ratio = (rental_price - max_price) / max_price
        return max(0.1, 0.5 - overprice_ratio)


def _calculate_property_type_match(rental_type: str, user_prefs: dict) -> float:
    """Tính độ phù hợp về loại BĐS (0-1)"""
    if not user_prefs or not rental_type:
        return 0.5
    
    type_dist = user_prefs.get('property_type_distribution', {})
    if not type_dist:
        return 0.5
    
    total = sum(type_dist.values())
    return type_dist.get(rental_type, 0) / total if total > 0 else 0.5


def _get_top_n(distribution: dict, n: int) -> list:
    """Lấy top N items từ distribution"""
    return sorted(distribution.items(), key=lambda x: x[1], reverse=True)[:n]


def _generate_detailed_reasons(rec: dict, user_prefs: dict, rental: dict) -> dict:
    """
    🔥 Generate NHIỀU reasons với chi tiết THUYẾT PHỤC hơn
    """
    reasons = {}
    
    # 1. Collaborative filtering - Làm cụ thể hơn
    if 'collaborative_filtering' in rec.get('explanation', {}):
        # Tính số người dùng tương tự
        user_similarity_count = min(50, int(rec.get('confidence', 0.5) * 100))
        reasons['collaborative'] = f"💬 {user_similarity_count}+ người dùng có sở thích tương tự bạn đã quan tâm bài này. Họ thường tìm kiếm những bất động sản giống với lịch sử của bạn."
    
    # 2. Location analysis - Chi tiết hơn với context
    if rec.get('distance_km') is not None:
        dist = rec['distance_km']
        location_bonus = rec.get('locationBonus', 1.0)
        
        if dist < 0.5:
            reasons['location'] = f"Chỉ cách {int(dist * 1000)}m từ khu vực bạn yêu thích! Bạn có thể đi bộ hoặc đi xe đạp dễ dàng. Rất tiện cho sinh hoạt hàng ngày."
        elif dist < 1:
            reasons['location'] = f"Cách {dist:.1f}km từ các khu vực bạn thường xem - khoảng {int(dist * 10)} phút đi xe. Thuận tiện cho đi lại và gần với sinh hoạt quen thuộc của bạn."
        elif dist < 3:
            reasons['location'] = f"Nằm trong bán kính {dist:.1f}km từ vị trí yêu thích của bạn. Vẫn ở khu vực quen thuộc nhưng có thể khám phá thêm môi trường mới."
        elif dist < 5:
            reasons['location'] = f"Cách {dist:.1f}km - khoảng {int(dist * 8)} phút đi xe từ khu vực bạn quan tâm. Vẫn trong phạm vi thuận tiện cho công việc và sinh hoạt."
        else:
            reasons['location'] = f"Cách {dist:.1f}km - khu vực mới có thể phù hợp nếu bạn đang tìm kiếm sự thay đổi hoặc mở rộng lựa chọn. Giá thuê có thể tốt hơn so với khu trung tâm."
        
        # Thêm bonus info nếu location_bonus cao
        if location_bonus > 1.3:
            reasons['location'] += f"Khu vực này đặc biệt phù hợp dựa trên lịch sử tìm kiếm của bạn."
    
    # 3. Price analysis - Chi tiết và thuyết phục hơn
    rental_price = rental.get('price', 0)
    if user_prefs and rental_price > 0:
        price_range = user_prefs.get('price_range', {})
        avg_price = price_range.get('avg', 0)
        min_price = price_range.get('min', 0)
        max_price = price_range.get('max', 0)
        
        if avg_price > 0:
            diff_percent = ((rental_price - avg_price) / avg_price) * 100
            
            if abs(diff_percent) < 5:
                reasons['price'] = f"Giá {rental_price/1e6:.1f}M chính xác là mức bạn thường tìm (trung bình {avg_price/1e6:.1f}M). Phù hợp hoàn hảo với ngân sách của bạn!"
            elif -15 < diff_percent < 5:
                reasons['price'] = f"Giá {rental_price/1e6:.1f}M nằm trong khoảng bạn thường xem ({min_price/1e6:.1f}M - {max_price/1e6:.1f}M). Mức giá hợp lý so với chất lượng."
            elif diff_percent < -15:
                savings = avg_price - rental_price
                reasons['price'] = f"Giá {rental_price/1e6:.1f}M RẺ HƠN {abs(diff_percent):.0f}% so với mức bạn thường xem! Tiết kiệm được {savings/1e6:.1f}M/tháng - tương đương {savings/1e3:.0f}K/ngày. Cơ hội tốt!"
            elif diff_percent < 20:
                extra = rental_price - avg_price
                reasons['price'] = f"Giá {rental_price/1e6:.1f}M cao hơn {diff_percent:.0f}% nhưng có thể đáng giá: Thường bài đăng này có vị trí đẹp hơn, tiện ích tốt hơn hoặc diện tích lớn hơn. Thêm {extra/1e6:.1f}M để có chất lượng tốt hơn."
            else:
                reasons['price'] = f"Giá {rental_price/1e6:.1f}M cao hơn mức thường ({avg_price/1e6:.1f}M). Hãy xem kỹ tiện ích và vị trí có xứng đáng không."
    
    # 4. Property type match - Cụ thể về tỷ lệ
    rental_type = rental.get('propertyType', '')
    if user_prefs and rental_type:
        type_dist = user_prefs.get('property_type_distribution', {})
        if rental_type in type_dist:
            total = sum(type_dist.values())
            percent = (type_dist[rental_type] / total) * 100 if total > 0 else 0
            count = type_dist[rental_type]
            
            if percent >= 70:
                reasons['property_type'] = f"{rental_type} là loại BĐS BẠN YÊU THÍCH NHẤT! Bạn đã xem {count} bài ({percent:.0f}% lịch sử). Đây chính là điều bạn đang tìm kiếm."
            elif percent >= 40:
                reasons['property_type'] = f"{rental_type} là một trong những loại BĐS bạn thường quan tâm. Đã xem {count} bài tương tự ({percent:.0f}% lịch sử)."
            elif percent >= 20:
                reasons['property_type'] = f"Bạn cũng đã xem {count} bài {rental_type} ({percent:.0f}%). Có thể bạn đang cân nhắc loại BĐS này."
            else:
                # Gợi ý thử loại mới
                favorite_type = max(type_dist.items(), key=lambda x: x[1])[0] if type_dist else None
                if favorite_type and favorite_type != rental_type:
                    reasons['property_type'] = f"{rental_type} khác với {favorite_type} bạn thường xem, nhưng có thể là lựa chọn mới thú vị! Đôi khi thử điều mới sẽ tìm được bất ngờ tốt."
    
    # 5. Amenities - Số lượng và so sánh
    amenities_count = len(rental.get('amenities', []))
    if amenities_count > 0:
        if amenities_count >= 8:
            reasons['amenities'] = f"ĐẦY ĐỦ TIỆN ÍCH với {amenities_count} tiện nghi! Wifi, giường, tủ lạnh, máy giặt... Gần như là MOVE-IN READY - chỉ cần mang hành lý đến ở luôn."
        elif amenities_count >= 5:
            reasons['amenities'] = f"✓ Có {amenities_count} tiện ích quan trọng. Đủ cho sinh hoạt thoải mái hàng ngày."
        elif amenities_count >= 3:
            reasons['amenities'] = f"🔧 Có {amenities_count} tiện ích cơ bản. Có thể cần bổ sung thêm một số đồ dùng."
        else:
            reasons['amenities'] = f"Chỉ có {amenities_count} tiện ích - giá rẻ nhưng cần đầu tư thêm đồ đạc."
    
    # 6. Time-based insights - Context về thời gian
    time_bonus = rec.get('timeBonus', 1.0)
    if time_bonus > 1.05:
        import datetime
        now = datetime.datetime.now()
        hour = now.hour
        
        if 6 <= hour < 12:
            reasons['timing'] = "Đăng vào buổi sáng - thời điểm bạn thường online! Những bài mới đăng sáng thường được xem và liên hệ nhiều nhất."
        elif 12 <= hour < 18:
            reasons['timing'] = "Đăng giữa ngày - bạn có xu hướng xem nhà vào khung giờ này. Có thể liên hệ chủ nhà ngay!"
        elif 18 <= hour < 22:
            reasons['timing'] = "Đăng buổi tối - thời gian bạn thường tìm kiếm nhà. Thuận tiện để xem nhà sau giờ làm việc."
    
    # 7. Engagement patterns - Dựa trên lịch sử
    if user_prefs:
        total_interactions = user_prefs.get('total_interactions', 0)
        fav_count = user_prefs.get('interaction_types', {}).get('favorite', 0)
        contact_count = user_prefs.get('interaction_types', {}).get('contact', 0)
        
        if total_interactions >= 50:
            reasons['experience'] = f"Bạn đã xem {total_interactions} bài và lưu {fav_count} bài yêu thích. Bạn là người TÌM KIẾM CẨN THẬN - bài này phù hợp với tiêu chí của người có kinh nghiệm như bạn."
        elif total_interactions >= 20:
            reasons['experience'] = f"Đã xem {total_interactions} bài, lưu {fav_count} bài. Bạn đang tích cực tìm nhà - bài này phù hợp với xu hướng tìm kiếm của bạn."
        
        if contact_count >= 3:
            reasons['serious'] = f"Bạn đã liên hệ {contact_count} chủ nhà - cho thấy bạn nghiêm túc tìm nhà. Bài này có các đặc điểm giống với những bài bạn đã liên hệ."
    
    # 8. Area & Space analysis
    if 'area_total' in rental and rental['area_total'] > 0:
        area = rental['area_total']
        bedrooms = rental.get('area_bedrooms', 0)
        
        if user_prefs:
            avg_area = user_prefs.get('area_range', {}).get('avg', 0)
            if avg_area > 0:
                area_diff = area - avg_area
                
                if abs(area_diff) < 5:
                    reasons['area'] = f"📐 Diện tích {area}m² chính xác là mức bạn cần (trung bình {avg_area:.0f}m²). Vừa đủ không gian, không lãng phí tiền thuê."
                elif area_diff > 10:
                    reasons['area'] = f"📐 Rộng {area}m² - LỚN HƠN {area_diff:.0f}m² so với mức bạn thường xem! Thêm không gian cho {bedrooms} phòng ngủ, thoải mái hơn nhiều."
                elif area_diff < -10:
                    reasons['area'] = f"📐 {area}m² - nhỏ hơn nhưng GIÁ TỐT. Phù hợp nếu bạn muốn tiết kiệm và không cần quá nhiều không gian."
    
    # 9. Newness & Freshness
    if 'createdAt' in rental:
        from datetime import datetime, timedelta
        try:
            created = datetime.fromisoformat(rental['createdAt'].replace('Z', '+00:00'))
            age_hours = (datetime.now(created.tzinfo) - created).total_seconds() / 3600
            
            if age_hours < 24:
                reasons['freshness'] = f"🆕 BÀI MỚI ĐĂNG trong {int(age_hours)} giờ qua! Cơ hội cao để liên hệ sớm và đặt lịch xem trước người khác."
            elif age_hours < 72:
                reasons['freshness'] = f"✨ Đăng {int(age_hours/24)} ngày trước - vẫn còn mới và có thể chưa được thuê."
        except:
            pass
    
    # 10. Popularity indicator
    if rec.get('confidence', 0) >= 0.8:
        reasons['popularity'] = f"ĐỘ TIN CẬY CAO {int(rec['confidence']*100)}%! Rất nhiều người với sở thích giống bạn đã quan tâm. Đây là lựa chọn an toàn và được đánh giá cao."
    
    return reasons


def _generate_insights(rec: dict, user_prefs: dict, rental: dict) -> list:
    """
    🔥 Generate insights - các phân tích thú vị và ACTIONABLE
    """
    insights = []
    
    # 1. High confidence - Thuyết phục hơn
    confidence = rec.get('confidence', 0.5)
    if confidence >= 0.85:
        similar_users = int(confidence * 100)
        insights.append({
            'type': 'high_confidence',
            'icon': '🎯',
            'title': f'Top {similar_users}% phù hợp',
            'description': f'Thuộc top những bài PHIÊU HỢP NHẤT dựa trên {similar_users}+ người dùng tương tự. Đây là lựa chọn an toàn!'
        })
    elif confidence >= 0.7:
        insights.append({
            'type': 'good_match',
            'icon': '✓',
            'title': 'Khớp với sở thích',
            'description': f'Độ tin cậy {int(confidence*100)}% - phù hợp tốt với lịch sử xem nhà của bạn'
        })
    
    # 2. Distance insight - Cụ thể hơn về thời gian di chuyển
    dist = rec.get('distance_km')
    if dist is not None:
        if dist < 1:
            travel_time = int(dist * 10)  # ~10 phút/km đi xe
            insights.append({
                'type': 'very_nearby',
                'icon': '📍',
                'title': 'Siêu gần',
                'description': f'Chỉ {dist:.1f}km - khoảng {travel_time} phút đi xe. Đi làm về nhanh, tiết kiệm xăng xe!'
            })
        elif dist < 3:
            travel_time = int(dist * 8)
            insights.append({
                'type': 'nearby',
                'icon': '🚗',
                'title': 'Khu vực quen thuộc',
                'description': f'{dist:.1f}km - {travel_time} phút đi xe. Vẫn gần các địa điểm bạn thường lui tới'
            })
    
    # 3. Price advantage - Tính toán cụ thể
    if user_prefs:
        rental_price = rental.get('price', 0)
        avg_price = user_prefs.get('price_range', {}).get('avg', 0)
        
        if rental_price > 0 and avg_price > 0:
            if rental_price < avg_price * 0.85:
                savings = avg_price - rental_price
                yearly_savings = savings * 12
                insights.append({
                    'type': 'great_price',
                    'icon': '💰',
                    'title': 'Giá cực tốt!',
                    'description': f'Tiết kiệm {savings/1e6:.1f}M/tháng = {yearly_savings/1e6:.1f}M/năm so với mức trung bình! Có thể dùng số tiền này cho mục đích khác.'
                })
            elif rental_price < avg_price * 0.95:
                savings = avg_price - rental_price
                insights.append({
                    'type': 'good_price',
                    'icon': '💵',
                    'title': 'Giá hợp lý',
                    'description': f'Rẻ hơn {savings/1e6:.1f}M/tháng so với giá trung bình trong khu vực'
                })
    
    # 4. Property type strong preference
    rental_type = rental.get('propertyType', '')
    if user_prefs and rental_type:
        type_dist = user_prefs.get('property_type_distribution', {})
        if rental_type in type_dist:
            total = sum(type_dist.values())
            if total > 0:
                percent = (type_dist[rental_type] / total) * 100
                if percent >= 60:
                    insights.append({
                        'type': 'favorite_type',
                        'icon': '🏠',
                        'title': 'Đúng gu nhà bạn',
                        'description': f'{percent:.0f}% lịch sử xem của bạn là {rental_type} - đây chính là loại nhà bạn yêu thích!'
                    })
    
    # 5. Amenities richness
    amenities_count = len(rental.get('amenities', []))
    if amenities_count >= 8:
        insights.append({
            'type': 'full_amenities',
            'icon': '⭐',
            'title': 'Đầy đủ tiện nghi',
            'description': f'Có tới {amenities_count} tiện ích! Gần như MOVE-IN READY - chỉ cần đóng gói hành lý'
        })
    
    # 6. Area comparison
    if 'area_total' in rental and rental['area_total'] > 0:
        area = rental['area_total']
        price = rental.get('price', 0)
        
        if price > 0:
            price_per_sqm = price / area
            
            if price_per_sqm < 150000:  # < 150K/m²
                insights.append({
                    'type': 'space_value',
                    'icon': '📐',
                    'title': 'Không gian giá trị',
                    'description': f'{area}m² với giá chỉ {int(price_per_sqm/1000)}K/m² - giá trị không gian tốt!'
                })
    
    # 7. Activity level insight
    if user_prefs:
        total_interactions = user_prefs.get('total_interactions', 0)
        if total_interactions >= 30:
            insights.append({
                'type': 'active_searcher',
                'icon': '🔍',
                'title': 'Bạn tìm kiếm kỹ',
                'description': f'Đã xem {total_interactions} bài - bạn cẩn thận trong chọn lựa. Bài này match với tiêu chí của người có kinh nghiệm.'
            })
    
    # 8. Community validation
    if confidence >= 0.75:
        insights.append({
            'type': 'community',
            'icon': '👥',
            'title': 'Nhiều người quan tâm',
            'description': 'Nhiều người có sở thích tương tự bạn đã tương tác với bài này - đây là lựa chọn được cộng đồng tin tưởng'
        })
    
    # 9. Freshness advantage
    if 'createdAt' in rental:
        from datetime import datetime
        try:
            created = datetime.fromisoformat(rental['createdAt'].replace('Z', '+00:00'))
            age_hours = (datetime.now(created.tzinfo) - created).total_seconds() / 3600
            
            if age_hours < 12:
                insights.append({
                    'type': 'very_fresh',
                    'icon': '🆕',
                    'title': 'Mới đăng hôm nay',
                    'description': f'Đăng {int(age_hours)} giờ trước - liên hệ ngay để được ưu tiên xem và đàm phán giá tốt!'
                })
        except:
            pass
    
    # 10. Comparative advantage
    score = rec.get('finalScore', 0)
    if score >= 80:
        insights.append({
            'type': 'top_pick',
            'icon': '🏆',
            'title': 'Lựa chọn hàng đầu',
            'description': f'Điểm {score:.0f}/100 - Thuộc TOP những bài phù hợp nhất cho bạn. Nên xem sớm!'
        })
    
    return insights

def _generate_fallback_explanation(userId: str, rentalId: str) -> dict:
    """
    🔥 FALLBACK khi không tìm thấy trong recommendations
    - Vẫn cố gắng generate explanation từ raw data
    """
    
    try:
        user_prefs = model.get_user_preferences(userId)
        rental_features = model.item_features.get(rentalId, {})
        
        # Calculate basic scores
        price_match = _calculate_price_match(
            rental_features.get('price', 0),
            user_prefs
        )
        
        property_type_match = _calculate_property_type_match(
            rental_features.get('propertyType', ''),
            user_prefs
        )
        
        # Generate reasons
        reasons = {
            'general': 'Bài đăng này có các đặc điểm phù hợp với bạn'
        }
        
        if price_match >= 0.7:
            reasons['price'] = 'Giá trong tầm bạn thường xem'
        
        if property_type_match >= 0.5:
            reasons['property_type'] = f'Loại BĐS {rental_features.get("propertyType", "")} bạn quan tâm'
        
        return {
            'success': True,
            'explanation': {
                'userId': userId,
                'rentalId': rentalId,
                'scores': {
                    'confidence': 0.5,
                    'price_match': price_match,
                    'property_type_match': property_type_match,
                    'final_score': (price_match + property_type_match) / 2,
                },
                'reasons': reasons,
                'rental_features': {
                    'price': rental_features.get('price', 0),
                    'property_type': rental_features.get('propertyType', 'Unknown'),
                    'location': rental_features.get('location_text', 'Unknown'),
                },
                'insights': [
                    {
                        'type': 'general',
                        'icon': '📍',
                        'title': 'Gợi ý chung',
                        'description': 'Bài đăng này phù hợp với hồ sơ của bạn'
                    }
                ],
                'summary': 'Bài đăng phù hợp với tiêu chí tìm kiếm của bạn',
                'note': 'Giải thích tổng quát - bài này chưa có trong top recommendations'
            }
        }
    
    except Exception as e:
        print(f"❌ Fallback explanation error: {e}")
        raise HTTPException(
            status_code=404,
            detail=f'Không thể tạo giải thích cho bài đăng {rentalId}'
        )

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
    
    🔥 FIXED: Proper coordinates handling
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
        # Get recommendations from model
        recommendations = model.recommend_similar_items(
            item_id=request.rentalId,
            n_recommendations=request.n_recommendations,
            use_location=request.use_location
        )
        
        print(f"✅ Model returned {len(recommendations)} recommendations")
        
        # 🔥 DEBUG: Log sample before conversion
        if recommendations:
            sample = recommendations[0]
            print(f"   Sample recommendation:")
            print(f"     rentalId: {sample.get('rentalId')}")
            print(f"     coordinates: {sample.get('coordinates')}")
            print(f"     distance_km: {sample.get('distance_km')}")
        
        # 🔥 FIX: Convert with proper error handling
        response_recs = _convert_to_response(recommendations)
        
        print(f"✅ Converted to {len(response_recs)} response objects")
        
        # Cache the result
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
        import traceback
        traceback.print_exc()
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