
import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/models/rental.dart';
import 'package:flutter_rentalhouse/services/AI_Chat_service.dart';
import 'package:flutter_rentalhouse/services/chat_ai_service.dart';
import 'package:flutter_rentalhouse/views/rental_detail_view.dart';
import 'package:intl/intl.dart';
import 'package:location/location.dart' as loc;

class ChatAIBottomSheet extends StatefulWidget {
  const ChatAIBottomSheet({super.key});

  @override
  State<ChatAIBottomSheet> createState() => _ChatAIBottomSheetState();
}

class _ChatAIBottomSheetState extends State<ChatAIBottomSheet> {
  List<Map<String, dynamic>> messages = [];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool isLoading = false;
  String? conversationId;
  List<String> suggestions = [];

  //  Add location fields
  double? currentLatitude;
  double? currentLongitude;
  bool isLocationAvailable = false;

  static const int _initialShowCount = 5;
  Map<String, int> _rentalGroupShowCount = {};
  // =======================

  @override
  void initState() {
    super.initState();
    _initializeConversation();
    _getCurrentLocation();
  }
  Future<void> _getCurrentLocation() async {
    try {
      loc.Location location = loc.Location();

      // Check if service is enabled
      bool serviceEnabled = await location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await location.requestService();
        if (!serviceEnabled) {
          print('⚠️ Location service is disabled');
          setState(() {
            isLocationAvailable = false;
          });
          return;
        }
      }

      // Check permission
      loc.PermissionStatus permissionGranted = await location.hasPermission();
      if (permissionGranted == loc.PermissionStatus.denied) {
        permissionGranted = await location.requestPermission();
        if (permissionGranted != loc.PermissionStatus.granted) {
          print('⚠️ Location permission denied');
          setState(() {
            isLocationAvailable = false;
          });
          return;
        }
      }

      // Get location
      final locationData = await location.getLocation();

      setState(() {
        currentLatitude = locationData.latitude;
        currentLongitude = locationData.longitude;
        isLocationAvailable = true;
      });

      print('✅ Location available: ($currentLatitude, $currentLongitude)');

    } catch (e) {
      print('⚠️ Could not get location: $e');
      setState(() {
        isLocationAvailable = false;
      });
    }
  }
  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// 🆕 Khởi tạo cuộc hội thoại
  Future<void> _initializeConversation() async {
    try {
      print('🆕 Initializing conversation...');

      final response = await ChatAIService.startConversation(
        initialContext: {
          'device': 'mobile',
          'platform': 'flutter',
        },
      );

      setState(() {
        conversationId = response.conversationId;
        messages.add({
          'role': 'assistant',
          'text': response.greeting,
        });
      });

      print('✅ Conversation initialized: $conversationId');
      _loadSuggestions();
    } catch (e) {
      print('❌ Error initializing conversation: $e');

      setState(() {
        messages.add({
          'role': 'assistant',
          'text': '👋 Xin chào! Tôi là trợ lý AI chuyên về bất động sản. '
              'Tôi có thể giúp bạn tìm nhà trọ/căn hộ phù hợp. '
              'Bạn đang tìm kiếm gì nhé?',
        });
      });
    }
  }

  /// 💡 Load suggestions
  Future<void> _loadSuggestions() async {
    try {
      const userId = 'current_user';
      final loadedSuggestions = await ChatAIService.getSuggestions(userId);
      setState(() {
        suggestions = loadedSuggestions;
      });
    } catch (e) {
      print('⚠️ Error loading suggestions: $e');
    }
  }

  String formatCurrency(double amount) {
    final formatter = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: '₫',
      decimalDigits: 0,
    );
    return formatter.format(amount);
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 150), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  /// 💬 Send message - FIXED VERSION
  Future<void> sendMessage() async {
    final userInput = _controller.text.trim();

    print('═════════════════════════════════════════════');
    print('💬 CHAT AI MESSAGE SENT');
    print('📝 Input: "$userInput"');
    print('🆔 Conversation ID: $conversationId');
    print('📍 Location: ${isLocationAvailable ? "Available" : "Not available"}');
    print('═════════════════════════════════════════════');

    if (userInput.isEmpty) return;

    setState(() {
      isLoading = true;
      messages.add({'role': 'user', 'text': userInput});
      _controller.clear();
    });

    _scrollToBottom();

    try {
      final conversationHistory = messages
          .where((msg) => msg['role'] == 'user' || msg['role'] == 'assistant')
          .map((msg) => ChatMessage(
        role: msg['role'],
        content: msg['text'],
      ))
          .toList();

      // 🔥 UPDATED: Pass location to chat service
      final response = await ChatAIService.chat(
        message: userInput,
        conversationHistory: conversationHistory,
        conversationId: conversationId,
        includeRecommendations: true,
        latitude: currentLatitude,  // 🔥 NEW
        longitude: currentLongitude,  // 🔥 NEW
      );

      print('✅ Chat response received');
      print('📄 Message: ${response.message}');
      print('🏠 Recommendations: ${response.recommendations?.length ?? 0}');
      print('🎯 Should recommend: ${response.shouldRecommend}');

      setState(() {
        isLoading = false;

        // Add AI response message
        messages.add({
          'role': 'assistant',
          'text': response.message,
        });

        // Add recommendations if available
        if (response.recommendations != null && response.recommendations!.isNotEmpty) {
          print('🏠 Processing ${response.recommendations!.length} rental cards...');

          final allRentals = response.recommendations!;
          final groupId = DateTime.now().millisecondsSinceEpoch.toString();

          // Khởi tạo showCount cho group này
          _rentalGroupShowCount[groupId] = 5;  // ban đầu hiện 5

          // Header
          messages.add({
            'role': 'system',
            'type': 'rental_header',
            'count': allRentals.length,
            'groupId': groupId,
          });

          // Toàn bộ list (không take(5) nữa)
          messages.add({
            'role': 'system',
            'type': 'rental_list',
            'rentals': allRentals,
            'groupId': groupId,
          });

          // Explanation
          if (response.explanation != null && response.explanation!.isNotEmpty) {
            messages.add({
              'role': 'assistant',
              'text': '💡 ${response.explanation}',
            });
          }
        }

        // Update conversationId
        if (response.conversationId != null) {
          conversationId = response.conversationId;
        }
      });

      _scrollToBottom();
    } catch (e) {
      print('❌ Error in sendMessage: $e');
      setState(() {
        isLoading = false;
        messages.add({
          'role': 'assistant',
          'text': '❌ Xin lỗi, tôi gặp chút vấn đề kỹ thuật. '
              'Bạn có thể thử lại không? 🙏',
        });
      });
      _scrollToBottom();
    }
  }


  /// 💡 Handle suggestion tap
  void _onSuggestionTap(String suggestion) {
    _controller.text = suggestion;
    sendMessage();
  }

  /// Build message item - FIXED
  Widget _buildMessageItem(BuildContext context, Map<String, dynamic> msg) {

    // NÚT XEM THÊM ============================= <
    if (msg['type'] == 'rental_list' && msg['rentals'] != null) {
      final rentals = msg['rentals'] as List<Rental>;
      final groupId = msg['groupId'] as String;

      return StatefulBuilder(
        builder: (context, setLocalState) {
          // 🔥 ĐỌC showCount BÊN TRONG builder (không được đọc bên ngoài)
          final showCount = _rentalGroupShowCount[groupId] ?? _initialShowCount;
          final displayRentals = rentals.take(showCount).toList();

          return Column(
            children: [
              ...displayRentals.map((rental) => _ModernRentalCard(

                rental: rental,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RentalDetailScreen(rental: rental),
                  ),
                ),
              )),

              // NÚT XEM THÊM
              if (showCount < rentals.length)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  child: InkWell(
                    onTap: () {
                      // 🔥 GỌI CẢ HAI setState để rebuild đúng
                      setState(() {
                        _rentalGroupShowCount[groupId] =
                            (showCount + 5).clamp(0, rentals.length);
                      });
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.blue[700]!, Colors.blue[500]!],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.expand_more, color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Xem thêm ${rentals.length - showCount} bài đăng',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // ĐÃ HIỆN HẾT
              if (showCount >= rentals.length && rentals.length > _initialShowCount)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, color: Colors.green[600], size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'Đã hiển thị tất cả ${rentals.length} bài đăng',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      );
    }
    // 🏠 RENTAL HEADER
    if (msg['type'] == 'rental_header') {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue[700],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.home, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Gợi Ý Bài Đăng Phù Hợp',
                        style:
                        Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[700],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tôi tìm thấy ${msg['count']} bài đăng phù hợp nhất',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              height: 3,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue[700]!, Colors.blue[100]!],
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      );
    }

    // 🏠 RENTAL CARD
    if (msg['type'] == 'rental_card' && msg['rental'] != null) {
      final rentalData = msg['rental'] as Rental;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        child: _RentalSuggestionCard(
          rental: rentalData,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => RentalDetailScreen(rental: rentalData),
              ),
            );
          },
        ),
      );
    }

    // 💬 TEXT MESSAGES
    final isUser = msg['role'] == 'user';

    return Container(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isUser ? Colors.blue[700] : Colors.grey[100],
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: isUser
                  ? Colors.blue.withOpacity(0.2)
                  : Colors.grey.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          msg['text'] ?? '',
          style: TextStyle(
            color: isUser ? Colors.white : Colors.black87,
            fontSize: 15,
            height: 1.4,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.all(16),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.95, // 95% chiều cao màn hình
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ===== HEADER =====
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Image.asset("assets/img/chatbox.png",
                        width: 45, height: 45),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Trợ lý AI Bất Động Sản",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          "Giải đáp và tư vấn tìm kiếm bất động sản",
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 12),

            // ===== SUGGESTIONS =====
            if (suggestions.isNotEmpty && messages.length <= 2)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '💡 Gợi ý câu hỏi:',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // 🔥 NEW: Location-based suggestions
                    if (isLocationAvailable)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _SuggestionChip(
                              icon: Icons.location_on,
                              label: 'Gần vị trí của tôi',
                              color: Colors.blue,
                              onTap: () => _onSuggestionTap('Tìm nhà trọ gần vị trí hiện tại của tôi'),
                            ),
                            _SuggestionChip(
                              icon: Icons.school,
                              label: 'Gần trường học',
                              color: Colors.orange,
                              onTap: () => _onSuggestionTap('Tìm nhà gần trường học'),
                            ),
                            _SuggestionChip(
                              icon: Icons.local_hospital,
                              label: 'Gần bệnh viện',
                              color: Colors.red,
                              onTap: () => _onSuggestionTap('Tìm nhà gần bệnh viện'),
                            ),
                            _SuggestionChip(
                              icon: Icons.shopping_cart,
                              label: 'Gần siêu thị',
                              color: Colors.green,
                              onTap: () => _onSuggestionTap('Tìm nhà gần siêu thị'),
                            ),
                          ],
                        ),
                      ),

                    // Original suggestions
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: suggestions.take(4).map((suggestion) {
                        return InkWell(
                          onTap: () => _onSuggestionTap(suggestion),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.blue[200]!,
                                width: 1,
                              ),
                            ),
                            child: Text(
                              suggestion,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue[700],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),

            // ===== MESSAGES - USING _buildMessageItem =====
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                shrinkWrap: true,
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  return _buildMessageItem(context, messages[index]);
                },
              ),
            ),

            // ===== LOADING INDICATOR =====
            if (isLoading)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.blue[700]!,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'AI đang xử lý...',
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            // ===== INPUT FIELD =====
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 9.0,
                vertical: 10.0,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _controller,
                  maxLines: null,
                  textInputAction: TextInputAction.send,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    hintText: "Tôi cần tìm nhà...",
                    hintStyle: TextStyle(color: Colors.grey[500]),
                    border: InputBorder.none,
                    suffixIcon: Padding(
                      padding: const EdgeInsets.only(right: 10.0),
                      child: CircleAvatar(
                        radius: 18,
                        backgroundColor:
                        isLoading ? Colors.grey : Colors.blue[700],
                        child: IconButton(
                          icon: Icon(
                            isLoading ? Icons.hourglass_empty : Icons.send,
                            color: Colors.white,
                            size: 20,
                          ),
                          onPressed: isLoading ? null : sendMessage,
                        ),
                      ),
                    ),
                  ),
                  onSubmitted: (_) => isLoading ? null : sendMessage(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============== MODERN RENTAL SUGGESTION CARD ==============
class _RentalSuggestionCard extends StatelessWidget {
  final Rental rental;
  final VoidCallback? onTap;

  const _RentalSuggestionCard({
    required this.rental,
    this.onTap,
  });

  String formatCurrency(double amount) {
    final formatter = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: '₫',
      decimalDigits: 0,
    );
    return formatter.format(amount);
  }

  String formatPrice(double price) {
    if (price >= 1000000000) {
      return '${(price / 1000000000).toStringAsFixed(1)} tỷ';
    } else if (price >= 1000000) {
      return '${(price / 1000000).toStringAsFixed(1)} triệu';
    }
    return formatCurrency(price);
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = rental.images.isNotEmpty
        ? rental.images[0]
        : 'https://via.placeholder.com/400x250?text=No+Image';

    final area = rental.area['total']?.toString() ?? '0';
    final bedrooms = rental.area['bedrooms']?.toString() ?? '0';
    final bathrooms = rental.area['bathrooms']?.toString() ?? '0';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // ===== IMAGE SECTION =====
              Stack(
                children: [
                  // Main Image
                  Container(
                    height: 180,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      image: DecorationImage(
                        image: NetworkImage(imageUrl),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),

                  // Gradient Overlay
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 100,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.7),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Property Type Badge - Top Left
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue[700]?.withOpacity(0.95),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Text(
                        rental.propertyType,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),

                  // AI Badge - Top Right (if AI recommended)
                  if (rental.isAIRecommended == true)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.purple[600]?.withOpacity(0.95),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.psychology, size: 12, color: Colors.white),
                            SizedBox(width: 3),
                            Text(
                              'AI',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Price Tag - Bottom Left
                  Positioned(
                    bottom: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            formatPrice(rental.price),
                            style: TextStyle(
                              color: Colors.red[700],
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // ===== CONTENT SECTION =====
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      rental.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1a1a1a),
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Location
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_rounded,
                          size: 15,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            rental.location['short'] ?? 'Chưa cập nhật',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Amenities Row
                    Row(
                      children: [
                        if (area != '0') ...[
                          _InfoChip(
                            icon: Icons.square_foot,
                            label: '${area}m²',
                          ),
                          const SizedBox(width: 6),
                        ],
                        if (bedrooms != '0') ...[
                          _InfoChip(
                            icon: Icons.bed_rounded,
                            label: '$bedrooms PN',
                          ),
                          const SizedBox(width: 6),
                        ],
                        if (bathrooms != '0') ...[
                          _InfoChip(
                            icon: Icons.bathroom_rounded,
                            label: '$bathrooms WC',
                          ),
                        ],
                      ],
                    ),

                    // AI Confidence (if available)
                    if (rental.confidence != null && rental.confidence! > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.verified,
                                size: 13,
                                color: Colors.blue[700],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Độ phù hợp: ${(rental.confidence! * 100).toStringAsFixed(0)}%',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    const SizedBox(height: 10),

                    // Action Button
                    SizedBox(
                      width: double.infinity,
                      height: 38,
                      child: ElevatedButton(
                        onPressed: onTap,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[700],
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: EdgeInsets.zero,
                        ),
                        child: const Text(
                          'Xem Chi Tiết',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModernRentalCard extends StatelessWidget {
  final Rental rental;
  final VoidCallback? onTap;

  const _ModernRentalCard({super.key, required this.rental, this.onTap});

  String _formatPrice(double price) {
    if (price >= 1000000000) return '${(price / 1000000000).toStringAsFixed(1)} tỷ';
    if (price >= 1000000) return '${(price / 1000000).toStringAsFixed(1)}tr';
    return NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0).format(price);
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = rental.images.isNotEmpty
        ? rental.images[0]
        : 'https://via.placeholder.com/400x200?text=No+Image';
    final area = rental.area['total']?.toString() ?? '0';
    final bedrooms = rental.area['bedrooms']?.toString() ?? '0';
    final bathrooms = rental.area['bathrooms']?.toString() ?? '0';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ===== LEFT: IMAGE =====
                SizedBox(
                  width: 130,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.grey[200],
                          child: Icon(Icons.home_outlined, color: Colors.grey[400], size: 40),
                        ),
                      ),
                      // Gradient overlay
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerRight,
                            end: Alignment.centerLeft,
                            colors: [Colors.transparent, Colors.black.withOpacity(0.15)],
                          ),
                        ),
                      ),
                      // Property type badge
                      Positioned(
                        top: 10,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue[700],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            rental.propertyType,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      // AI badge
                      if (rental.isAIRecommended == true)
                        Positioned(
                          bottom: 10,
                          left: 8,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(100),
                            child: Image.asset(
                              "assets/img/ai.jpg",
                              width: 35,
                              height: 35,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // ===== RIGHT: CONTENT =====
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title
                        Text(
                          rental.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1a1a2e),
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 6),

                        // Location
                        Row(
                          children: [
                            Icon(Icons.place_outlined, size: 12, color: Colors.grey[500]),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                rental.location['short'] ?? '—',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Stats row
                        Row(
                          children: [
                            if (area != '0') _MiniChip(icon: Icons.square_foot, label: '${area}m²'),
                            if (area != '0') const SizedBox(width: 4),
                            if (bedrooms != '0') _MiniChip(icon: Icons.bed_outlined, label: bedrooms),
                            if (bedrooms != '0') const SizedBox(width: 4),
                            if (bathrooms != '0') _MiniChip(icon: Icons.bathroom_outlined, label: bathrooms),
                          ],
                        ),
                        const Spacer(),

                        // Price + CTA row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _formatPrice(rental.price),
                                  style: TextStyle(
                                    color: Colors.red[700],
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (rental.confidence != null && rental.confidence! > 0)
                                  Text(
                                    'Phù hợp ${(rental.confidence! * 100).toStringAsFixed(0)}%',
                                    style: TextStyle(fontSize: 10, color: Colors.blue[600]),
                                  ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                              decoration: BoxDecoration(
                                color: Colors.blue[700],
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                'Xem',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MiniChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: Colors.grey[600]),
          const SizedBox(width: 3),
          Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[700], fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
// ============== INFO CHIP WIDGET ==============
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: Colors.grey[300]!,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 13,
            color: Colors.grey[700],
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }
}
class _SuggestionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _SuggestionChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.3), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}