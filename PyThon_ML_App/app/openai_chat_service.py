import os
import json
from typing import List, Dict, Any, Optional
from groq import Groq
from datetime import datetime
from dotenv import load_dotenv
import re

load_dotenv()

class RentalChatAssistant:
    """
    🤖 Enhanced AI Chat Assistant với Groq - ANTI-HALLUCINATION
    - Ngăn chặn AI tạo thông tin giả
    - Chỉ trả lời dựa trên data thực tế
    - Luôn redirect về database nếu không có kết quả
    """
    
    def __init__(self, model: Any = None):
        """Initialize Groq client"""
        api_key = os.getenv('GROQ_API_KEY')
        
        if not api_key:
            raise ValueError("❌ GROQ_API_KEY not found in .env file!")
        
        try:
            self.client = Groq(api_key=api_key)
            print(f"✅ Groq client initialized successfully")
        except Exception as e:
            raise ValueError(f"Groq client initialization failed: {e}")
        
        self.model = model
        self.chat_model = os.getenv('GROQ_MODEL', 'llama-3.3-70b-versatile')
        self.temperature = 0.3  # 🔥 LOWER để giảm hallucination
        self.max_tokens = 800   # 🔥 GIỚI HẠN để tránh dài dòng 
        
        print(f"✅ Enhanced Chat Assistant initialized")
        print(f"   Model: {self.chat_model}")
        print(f"   ML Model loaded: {self.model is not None}")
    
    def _get_system_prompt(self) -> str:
        """Enhanced system prompt - ANTI-HALLUCINATION"""
        return """Bạn là trợ lý AI chuyên nghiệp về bất động sản cho thuê tại Việt Nam.

⚠️ QUY TẮC QUAN TRỌNG NHẤT - KHÔNG BAO GIỜ VI PHẠM:

1. 🚫 KHÔNG BAO GIỜ TỰ Ý TẠO THÔNG TIN BÀI ĐĂNG
   - KHÔNG đưa ra danh sách bài đăng giả
   - KHÔNG tự nghĩ ra địa chỉ, giá cả, diện tích
   - KHÔNG nói "Tôi đã tìm thấy..." nếu KHÔNG có dữ liệu thực

2. ✅ CHỈ NÓI VỀ DỮ LIỆU THỰC TẾ:
   - Nếu KHÔNG có bài đăng phù hợp → Nói THẲNG là "Hiện chưa có bài nào"
   - Nếu CÓ bài đăng → Hệ thống sẽ hiển thị BẰNG CARD, ĐỪNG liệt kê
   - Nhiệm vụ của bạn: HỎI THÊM để thu thập preferences, KHÔNG tạo data

3. 💬 CÁCH TRẢ LỜI ĐÚNG:

KHI KHÔNG CÓ KẾT QUẢ:
- ❌ SAI: "Tôi tìm thấy: 1. Đất nền đường X giá Y..."
- ✅ ĐÚNG: "Hiện chưa có bài đăng đất nền phù hợp ở khu vực này. Bạn có thể thử mở rộng khu vực tìm kiếm hoặc tìm loại BĐS khác như nhà trọ, căn hộ không?"

KHI CÓ KẾT QUẢ:
- ❌ SAI: "Có 3 bài: 1. Nhà A giá X, 2. Nhà B giá Y..."
- ✅ ĐÚNG: "Tôi tìm thấy 3 bài phù hợp! Xem chi tiết bên dưới nhé. Bạn muốn tôi giải thích tại sao gợi ý những bài này không?"

4. 🎯 NHIỆM VỤ CHÍNH:
   - HỎI để hiểu rõ nhu cầu: giá, vị trí, diện tích, loại nhà
   - GỢI Ý mở rộng tìm kiếm nếu không có kết quả
   - GIẢI THÍCH các bài đăng hệ thống tìm được (nếu có)
   - TƯ VẤN về khu vực, giá thị trường (dựa trên kiến thức chung)

5. ⚡ LƯU Ý:
   - Luôn thân thiện, nhiệt tình
   - Dùng emoji vừa phải (1-2 emoji/câu)
   - Câu ngắn gọn, dễ hiểu
   - Ưu tiên HỎI hơn là NÓI

VÍ DỤ HỘI THOẠI ĐÚNG:

User: "Tìm đất nền dưới 1 tỷ ở Bình Thủy"
Bot: "Mình đang tìm đất nền dưới 1 tỷ ở Bình Thủy cho bạn... 🔍

[Hệ thống tìm kiếm...]

Hiện chưa có bài đăng đất nền phù hợp với yêu cầu này ở Bình Thủy. 

Bạn có muốn:
• Mở rộng khu vực sang Ninh Kiều, Cái Răng?
• Xem nhà riêng/nhà trọ giá phải chăng?
• Tăng ngân sách lên 1.5 tỷ để có nhiều lựa chọn hơn?"

LÀM ĐÚNG THẾ NÀY!"""
    
    def chat(
        self, 
        user_message: str, 
        conversation_history: List[Dict] = None,
        user_context: Dict = None
    ) -> Dict[str, Any]:
        """Enhanced chat với anti-hallucination check"""
        try:
            messages = [
                {"role": "system", "content": self._get_system_prompt()}
            ]
            
            # 🔥 ADD: Nhắc nhở về quy tắc TRƯỚC mỗi câu hỏi
            messages.append({
                "role": "system",
                "content": "⚠️ NHẮC LẠI: KHÔNG tự tạo thông tin bài đăng. Nếu không có kết quả, nói THẲNG và gợi ý mở rộng tìm kiếm."
            })
            
            if conversation_history:
                messages.extend(conversation_history)
            
            if user_context:
                context_msg = self._format_user_context(user_context)
                messages.append({
                    "role": "system", 
                    "content": f"Thông tin về user:\n{context_msg}"
                })
            
            messages.append({"role": "user", "content": user_message})
            
            print(f"\n🤖 [GROQ] Processing chat...")
            print(f"   User: {user_message[:100]}...")
            
            # Call Groq API với temperature THẤP
            response = self.client.chat.completions.create(
                model=self.chat_model,
                messages=messages,
                temperature=self.temperature,  # 0.3 để ổn định
                max_tokens=self.max_tokens,
                top_p=0.9,  # 🔥 Giảm randomness
            )
            
            ai_message = response.choices[0].message.content
            
            # 🔥 POST-PROCESSING: Kiểm tra hallucination
            ai_message = self._prevent_hallucination(ai_message, user_message)
            
            print(f"   AI: {ai_message[:100]}...")
            
            # Extract preferences
            preferences = self._extract_preferences_enhanced(user_message, ai_message)
            intent = self._classify_intent(user_message)
            should_recommend = self._should_recommend(user_message, ai_message, preferences)
            
            return {
                'message': ai_message,
                'intent': intent,
                'extracted_preferences': preferences,
                'should_recommend': should_recommend,
                'usage': {
                    'prompt_tokens': response.usage.prompt_tokens,
                    'completion_tokens': response.usage.completion_tokens,
                    'total_tokens': response.usage.total_tokens
                }
            }
            
        except Exception as e:
            print(f"❌ Error in chat: {e}")
            import traceback
            traceback.print_exc()
            return {
                'message': "Xin lỗi, tôi gặp chút vấn đề. Bạn có thể thử lại không?",
                'intent': 'error',
                'extracted_preferences': {},
                'should_recommend': False,
                'error': str(e)
            }
    
    def _prevent_hallucination(self, ai_message: str, user_message: str) -> str:
        """
        🔥 CRITICAL: Ngăn chặn AI tạo thông tin giả
        """
        # Patterns nguy hiểm cho thấy AI đang hallucinate
        hallucination_patterns = [
            r'Tôi (?:đã )?tìm thấy.*?:',
            r'Có \d+ (?:bài|lựa chọn).*?:',
            r'\d+\.\s+(?:Đất nền|Nhà|Căn hộ).*?đường.*?giá',
            r'(?:Đất nền|Nhà riêng|Căn hộ).*?ở đường.*?diện tích.*?giá',
            r'Dưới đây là.*?lựa chọn',
        ]
        
        # Check nếu AI đang tạo danh sách giả
        is_hallucinating = any(
            re.search(pattern, ai_message, re.IGNORECASE | re.MULTILINE)
            for pattern in hallucination_patterns
        )
        
        if is_hallucinating:
            print("⚠️ DETECTED HALLUCINATION! Replacing with safe response...")
            
            # Extract preferences từ user message
            prefs = self._extract_preferences_enhanced(user_message, "")
            
            # Tạo response an toàn
            safe_response = self._generate_safe_no_results_response(prefs)
            return safe_response
        
        return ai_message
    
    def _generate_safe_no_results_response(self, preferences: Dict) -> str:
        """Tạo response an toàn khi không có kết quả"""
        
        # Extract info từ preferences
        location = preferences.get('location', 'khu vực bạn chọn')
        price_range = preferences.get('price_range', {})
        property_type = preferences.get('property_type', 'bất động sản')
        
        # Format price
        price_text = ""
        if price_range:
            min_price = price_range.get('min', 0)
            max_price = price_range.get('max', 0)
            if max_price > 0:
                price_text = f"dưới {max_price/1e9:.1f} tỷ" if max_price >= 1e9 else f"dưới {max_price/1e6:.1f} triệu"
        
        # Tạo response
        parts = [
            f"Hiện tại chưa có bài đăng {property_type}",
            f"{price_text}" if price_text else "",
            f"ở {location} trong hệ thống.",
        ]
        
        response = " ".join(p for p in parts if p) + "\n\n"
        
        # Gợi ý hữu ích
        suggestions = []
        
        if location and location != 'khu vực bạn chọn':
            suggestions.append(f"• Mở rộng sang các quận/huyện lân cận {location}")
        
        if property_type and property_type != 'bất động sản':
            alternative_types = {
                'đất nền': 'nhà riêng, nhà trọ',
                'biệt thự': 'nhà riêng, căn hộ cao cấp',
                'căn hộ': 'nhà riêng, chung cư mini',
            }
            alt = alternative_types.get(property_type.lower(), 'loại hình khác')
            suggestions.append(f"• Xem {alt} để có nhiều lựa chọn hơn")
        
        if price_range and price_range.get('max'):
            max_price = price_range['max']
            new_max = max_price * 1.5
            new_max_text = f"{new_max/1e9:.1f} tỷ" if new_max >= 1e9 else f"{new_max/1e6:.1f} triệu"
            suggestions.append(f"• Tăng ngân sách lên khoảng {new_max_text}")
        
        suggestions.append("• Để lại thông tin để được tư vấn khi có bài mới phù hợp")
        
        response += "Bạn có thể thử:\n" + "\n".join(suggestions)
        
        return response
    
    def _extract_preferences_enhanced(self, user_msg: str, ai_msg: str) -> Dict:
        """
        🔥 ENHANCED: Trích xuất preferences chính xác hơn
        """
        preferences = {}
        msg_lower = user_msg.lower()
        
        # ===== 1. PRICE EXTRACTION =====
        price_patterns = [
            r'(\d+(?:\.\d+)?)\s*(?:-|đến|tới)\s*(\d+(?:\.\d+)?)\s*(?:tỷ|ty|billion)',
            r'dưới\s*(\d+(?:\.\d+)?)\s*(?:tỷ|ty|billion)',
            r'trên\s*(\d+(?:\.\d+)?)\s*(?:tỷ|ty|billion)',
            r'khoảng\s*(\d+(?:\.\d+)?)\s*(?:tỷ|ty|billion)',
            r'(\d+(?:\.\d+)?)\s*(?:tỷ|ty|billion)',
            r'(\d+)\s*(?:-|đến|tới)\s*(\d+)\s*(?:triệu|tr|trieu|m)',
            r'dưới\s*(\d+)\s*(?:triệu|tr|trieu|m)',
            r'trên\s*(\d+)\s*(?:triệu|tr|trieu|m)',
            r'khoảng\s*(\d+)\s*(?:triệu|tr|trieu|m)',
            r'(\d+)\s*(?:triệu|tr|trieu|m)',
        ]
        
        for pattern in price_patterns:
            match = re.search(pattern, msg_lower)
            if match:
                # Xử lý tỷ (billion)
                if 'tỷ' in pattern or 'ty' in pattern or 'billion' in pattern:
                    if len(match.groups()) >= 2 and match.group(2):
                        min_price = float(match.group(1)) * 1e9
                        max_price = float(match.group(2)) * 1e9
                    elif 'dưới' in pattern:
                        min_price = 0
                        max_price = float(match.group(1)) * 1e9
                    elif 'trên' in pattern:
                        min_price = float(match.group(1)) * 1e9
                        max_price = float(match.group(1)) * 2 * 1e9
                    elif 'khoảng' in pattern:
                        base = float(match.group(1)) * 1e9
                        min_price = base * 0.7
                        max_price = base * 1.3
                    else:
                        base = float(match.group(1)) * 1e9
                        min_price = base * 0.5
                        max_price = base * 1.5
                # Xử lý triệu (million)
                else:
                    if len(match.groups()) >= 2 and match.group(2):
                        min_price = int(match.group(1)) * 1e6
                        max_price = int(match.group(2)) * 1e6
                    elif 'dưới' in pattern:
                        min_price = 0
                        max_price = int(match.group(1)) * 1e6
                    elif 'trên' in pattern:
                        min_price = int(match.group(1)) * 1e6
                        max_price = int(match.group(1)) * 2 * 1e6
                    elif 'khoảng' in pattern:
                        base = int(match.group(1)) * 1e6
                        min_price = base * 0.7
                        max_price = base * 1.3
                    else:
                        base = int(match.group(1)) * 1e6
                        min_price = base * 0.5
                        max_price = base * 1.5
                
                preferences['price_range'] = {
                    'min': int(min_price),
                    'max': int(max_price)
                }
                print(f"   💰 Extracted price: {min_price/1e6:.1f}M - {max_price/1e6:.1f}M")
                break
        
        # ===== 2. LOCATION EXTRACTION =====
        cities = [
            'hà nội', 'hanoi', 'tp.hcm', 'tphcm', 'sài gòn', 'saigon',
            'cần thơ', 'can tho', 'đà nẵng', 'da nang', 'hải phòng',
            'biên hòa', 'nha trang', 'huế', 'vũng tàu'
        ]
        
        districts = [
            'ninh kiều', 'cái răng', 'bình thủy', 'ô môn', 'thốt nốt',
            'quận 1', 'quận 2', 'quận 3', 'quận 7', 'quận 10',
            'bình thạnh', 'tân bình', 'gò vấp', 'thủ đức'
        ]
        
        for city in cities:
            if city in msg_lower:
                preferences['location'] = city.title()
                print(f"   📍 Extracted location: {city.title()}")
                break
        
        if 'location' not in preferences:
            for district in districts:
                if district in msg_lower:
                    preferences['location'] = district.title()
                    print(f"   📍 Extracted district: {district.title()}")
                    break
        
        # ===== 3. PROPERTY TYPE EXTRACTION - EXPANDED =====
        property_types = {
            'đất nền': ['đất nền', 'dat nen', 'đất', 'dat'],
            'phòng trọ': ['phòng trọ', 'phong tro', 'nhà trọ', 'nha tro', 'trọ'],
            'chung cư': ['chung cư', 'chung cu', 'căn hộ', 'can ho', 'apartment'],
            'nhà riêng': ['nhà riêng', 'nha rieng', 'nhà nguyên căn', 'house'],
            'studio': ['studio', 'mini'],
            'biệt thự': ['biệt thự', 'biet thu', 'villa'],
            'mặt bằng': ['mặt bằng', 'mat bang', 'văn phòng', 'van phong'],
        }
        
        for ptype, keywords in property_types.items():
            if any(kw in msg_lower for kw in keywords):
                preferences['property_type'] = ptype
                print(f"   🏠 Extracted property type: {ptype}")
                break
        
        # ===== 4. AREA EXTRACTION =====
        area_patterns = [
            r'(\d+)\s*(?:m2|m²|mét|met)',
            r'(?:diện tích|dien tich)\s*(\d+)',
        ]
        
        for pattern in area_patterns:
            match = re.search(pattern, msg_lower)
            if match:
                area = int(match.group(1))
                preferences['area'] = area
                print(f"   📐 Extracted area: {area}m²")
                break
        
        # ===== 5. ROOMS EXTRACTION =====
        bedroom_patterns = [
            r'(\d+)\s*(?:phòng ngủ|phong ngu|pn)',
            r'(\d+)\s*(?:bedroom|bedrooms)',
        ]
        
        for pattern in bedroom_patterns:
            match = re.search(pattern, msg_lower)
            if match:
                bedrooms = int(match.group(1))
                preferences['bedrooms'] = bedrooms
                print(f"   🛏️ Extracted bedrooms: {bedrooms}")
                break
        
        # ===== 6. AMENITIES EXTRACTION =====
        amenities_keywords = {
            'wifi': ['wifi', 'wi-fi', 'internet'],
            'máy lạnh': ['máy lạnh', 'may lanh', 'điều hòa', 'dieu hoa', 'ac'],
            'giường': ['giường', 'giuong', 'bed'],
            'tủ lạnh': ['tủ lạnh', 'tu lanh', 'fridge'],
            'máy giặt': ['máy giặt', 'may giat', 'washing machine'],
            'bếp': ['bếp', 'bep', 'kitchen'],
            'ban công': ['ban công', 'ban cong', 'balcony'],
        }
        
        detected_amenities = []
        for amenity, keywords in amenities_keywords.items():
            if any(kw in msg_lower for kw in keywords):
                detected_amenities.append(amenity)
        
        if detected_amenities:
            preferences['amenities'] = detected_amenities
            print(f"   ✨ Extracted amenities: {', '.join(detected_amenities)}")
        
        # ===== 7. SEARCH RADIUS =====
        if 'location' in preferences:
            if any(kw in msg_lower for kw in ['gần', 'gan', 'nearby', 'close']):
                preferences['search_radius'] = 5
            else:
                preferences['search_radius'] = 20
        
    # ===== 9. LOCATION INTENT - NEW =====
        location_intent = self._extract_location_from_message(user_msg)
        if location_intent['wants_nearby']:
            preferences['wants_nearby_location'] = True
            preferences['needs_user_location'] = location_intent['needs_user_location']
            print(f"   📍 Location intent detected: nearby search")
        
        # ===== 10. POI INTENT - NEW =====
        poi_intent = self._extract_poi_from_message(user_msg)
        if poi_intent['has_poi_intent']:
            preferences['poi_categories'] = poi_intent['categories']
            preferences['wants_poi_filter'] = True
            print(f"   🏢 POI categories detected: {', '.join(poi_intent['categories'])}")
        
        return preferences
    
    def _classify_intent(self, user_msg: str) -> str:
        """Classify user intent"""
        msg_lower = user_msg.lower()
        
        # Search intent
        search_keywords = ['tìm', 'tim', 'thuê', 'thue', 'cần', 'can', 'muốn', 'muon']
        if any(kw in msg_lower for kw in search_keywords):
            return 'search'
        
        # Info intent
        if any(kw in msg_lower for kw in ['bài', 'bai', 'nhà này', 'nha nay']):
            return 'info'
        
        # Question intent
        if any(msg_lower.startswith(q) for q in ['sao', 'tại sao', 'tai sao', 'như thế nào', 'nhu the nao']):
            return 'ask'
        
        return 'chitchat'
    
    def _should_recommend(self, user_msg: str, ai_msg: str, preferences: Dict) -> bool:
        """Decide whether to recommend rentals"""
        msg_lower = user_msg.lower()
        
        # Explicit keywords
        explicit_keywords = ['gợi ý', 'goi y', 'tìm cho', 'tim cho', 'show', 'xem']
        if any(kw in msg_lower for kw in explicit_keywords):
            return True
        
        # Has enough preferences (at least 2)
        key_prefs = ['price_range', 'location', 'property_type']
        pref_count = sum(1 for key in key_prefs if key in preferences)
        
        return pref_count >= 2
    
    def _format_user_context(self, context: Dict) -> str:
        """Format user context"""
        parts = []
        if context.get('location'):
            parts.append(f"- Vị trí: {context['location']}")
        if context.get('price_range'):
            pr = context['price_range']
            parts.append(f"- Tầm giá: {pr['min']/1e6:.1f}M - {pr['max']/1e6:.1f}M")
        if context.get('favorite_property_type'):
            parts.append(f"- Loại nhà: {context['favorite_property_type']}")
        return "\n".join(parts) if parts else "Chưa có"
    
    def get_rental_recommendations_with_chat(
        self,
        user_id: str,
        preferences: Dict,
        conversation_context: str = "",
        n_recommendations: int = 5
    ) -> Dict[str, Any]:
        """Get rental recommendations based on chat preferences"""
        try:
            if not self.model:
                return {
                    'recommendations': [],
                    'explanation': "ML model chưa sẵn sàng",
                    'total': 0
                }
            
            print(f"\n🎯 Getting recommendations with preferences:")
            print(f"   {json.dumps(preferences, indent=2, ensure_ascii=False)}")
            
            # Call ML model
            ml_recommendations = self.model.recommend_for_user(
                user_id=user_id,
                n_recommendations=n_recommendations * 2,
                use_location=True,
                radius_km=preferences.get('search_radius', 20)
            )
            
            # Filter by chat preferences
            filtered = self._filter_by_chat_preferences(
                ml_recommendations,
                preferences
            )
            
            final_recs = filtered[:n_recommendations]
            
            return {
                'recommendations': final_recs,
                'explanation': f"Tôi tìm được {len(final_recs)} bài phù hợp!",
                'total': len(final_recs),
                'filters_applied': preferences
            }
            
        except Exception as e:
            print(f"❌ Error: {e}")
            return {
                'recommendations': [],
                'explanation': str(e),
                'total': 0
            }
    
    def _filter_by_chat_preferences(
        self,
        recommendations: List[Dict],
        preferences: Dict
    ) -> List[Dict]:
        """Filter recommendations by chat preferences"""
        filtered = recommendations.copy()
        
        # Price filter
        if preferences.get('price_range') and self.model:
            pr = preferences['price_range']
            filtered = [
                r for r in filtered 
                if pr['min'] <= self.model.item_features.get(r['rentalId'], {}).get('price', 0) <= pr['max']
            ]
            print(f"   💰 Price filter: {len(filtered)} rentals remain")
        
        # Property type filter
        if preferences.get('property_type') and self.model:
            ptype = preferences['property_type'].lower()
            filtered = [
                r for r in filtered
                if ptype in self.model.item_features.get(r['rentalId'], {}).get('propertyType', '').lower()
            ]
            print(f"   🏠 Property type filter: {len(filtered)} rentals remain")
        
        # Area filter
        if preferences.get('area') and self.model:
            min_area = preferences['area'] * 0.8
            max_area = preferences['area'] * 1.2
            filtered = [
                r for r in filtered
                if min_area <= self.model.item_features.get(r['rentalId'], {}).get('area', 0) <= max_area
            ]
            print(f"   📐 Area filter: {len(filtered)} rentals remain")
        
        return filtered

    def _extract_location_from_message(self, message: str) -> dict:
        """
        🔥 NEW: Extract location intent from user message
        """
        msg_lower = message.lower()
        
        location_keywords = {
            'nearby': ['gần đây', 'xung quanh', 'lân cận', 'nearby', 'around here'],
            'current': ['vị trí hiện tại', 'current location', 'nơi tôi đang ở'],
            'map': ['trên bản đồ', 'on map', 'map'],
        }
        
        # Check if asking for nearby recommendations
        wants_nearby = any(kw in msg_lower for kw in location_keywords['nearby'])
        wants_current = any(kw in msg_lower for kw in location_keywords['current'])
        wants_map = any(kw in msg_lower for kw in location_keywords['map'])
        
        return {
            'wants_nearby': wants_nearby or wants_current or wants_map,
            'needs_user_location': True
        }

    def _extract_poi_from_message(self, message: str) -> dict:
        """
        🔥 NEW: Extract POI categories from user message
        """
        msg_lower = message.lower()
        
        poi_keywords = {
            'EDUCATION': ['trường', 'school', 'university', 'đại học', 'học'],
            'HOSPITAL': ['bệnh viện', 'hospital', 'phòng khám', 'clinic', 'y tế'],
            'TRANSPORT': ['xe buýt', 'bus', 'tàu điện', 'subway', 'giao thông'],
            'SHOPPING': ['siêu thị', 'supermarket', 'chợ', 'market', 'mua sắm'],
            'RESTAURANT': ['quán ăn', 'restaurant', 'cafe', 'ăn uống'],
            'PARK': ['công viên', 'park', 'garden'],
            'BANK': ['ngân hàng', 'bank', 'atm'],
            'GYM': ['gym', 'thể thao', 'fitness'],
        }
        
        detected_categories = []
        for category, keywords in poi_keywords.items():
            if any(kw in msg_lower for kw in keywords):
                detected_categories.append(category)
        
        return {
            'has_poi_intent': len(detected_categories) > 0,
            'categories': detected_categories
        }
    
    def explain_rental_detail(
        self,
        rental_id: str,
        user_preferences: Dict = None,
        conversation_context: str = ""
    ) -> str:
        """Explain a specific rental"""
        if not self.model or rental_id not in self.model.item_features:
            return "Xin lỗi, không tìm thấy thông tin bài này."
        
        rental = self.model.item_features[rental_id]
        
        explanation_parts = [
            f"📍 **Vị trí**: {rental.get('location_text', 'Không rõ')}",
            f"💰 **Giá**: {rental.get('price', 0)/1e6:.1f} triệu/tháng",
            f"🏠 **Loại**: {rental.get('propertyType', 'Không rõ')}",
            f"📐 **Diện tích**: {rental.get('area', 0)}m²",
        ]
        
        if rental.get('amenities'):
            amenities_count = len(rental['amenities'])
            explanation_parts.append(f"✨ **Tiện ích**: {amenities_count} tiện nghi")
        
        return "\n".join(explanation_parts)


if __name__ == '__main__':
    print("\n" + "="*70)
    print("🧪 TESTING ENHANCED GROQ CHAT ASSISTANT")
    print("="*70 + "\n")
    
    try:
        assistant = RentalChatAssistant(model=None)
        
        # Test extraction
        test_messages = [
            "Tôi cần tìm phòng trọ 2-3 triệu ở Ninh Kiều, có wifi và máy lạnh",
            "Tìm căn hộ dưới 5 triệu gần trường, diện tích khoảng 30m2",
            "Có nhà riêng nào tầm 4 triệu không?",
        ]
        
        for msg in test_messages:
            print(f"\n📝 Test message: {msg}")
            response = assistant.chat(
                user_message=msg,
                conversation_history=[],
                user_context=None
            )
            
            print(f"✅ AI: {response['message'][:100]}...")
            print(f"📊 Intent: {response['intent']}")
            print(f"🎯 Preferences: {json.dumps(response['extracted_preferences'], indent=2, ensure_ascii=False)}")
            print(f"💡 Should recommend: {response['should_recommend']}")
        
    except Exception as e:
        print(f"❌ Error: {e}")
        import traceback
        traceback.print_exc()
    
    print("\n" + "="*70)