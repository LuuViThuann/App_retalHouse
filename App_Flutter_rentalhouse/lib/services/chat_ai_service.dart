import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/services/AISuggestService.dart'; // ✅ FIX: Bỏ khoảng trắng
import 'package:flutter_rentalhouse/views/rental_detail_view.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:flutter_rentalhouse/models/rental.dart';

class ChatAIBottomSheet extends StatefulWidget {
  final String apiKey;

  const ChatAIBottomSheet({super.key, required this.apiKey});

  @override
  State<ChatAIBottomSheet> createState() => _ChatAIBottomSheetState();
}

class _ChatAIBottomSheetState extends State<ChatAIBottomSheet> {
  List<Map<String, dynamic>> messages = [];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    messages.add({
      'role': 'ai',
      'text':
      '👋 Xin chào! Tôi là trợ lý AI chuyên về bất động sản. Tôi có thể giúp bạn:\n\n'
          '🏠 Tìm kiếm nhà theo loại hình (căn hộ, nhà riêng, phòng trọ...)\n'
          '💰 Tìm nhà theo mức giá phù hợp\n'
          '📍 Tìm theo vị trí cụ thể\n'
          '📐 Tìm theo diện tích mong muốn\n'
          '✨ Tư vấn về tiện nghi và lựa chọn phù hợp\n\n'
          'Hãy cho tôi biết bạn đang tìm kiếm gì nhé!',
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String formatCurrency(double amount) {
    final formatter =
    NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);
    return formatter.format(amount);
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  Future<void> sendMessage() async {
    final userInput = _controller.text.trim();

    // ✅ ADD DEBUG LOG
    print('═════════════════════════════════════════════');
    print('💬 CHAT AI MESSAGE SENT');
    print('📝 Input: "$userInput"');
    print('📏 Length: ${userInput.length}');
    print('═════════════════════════════════════════════');

    if (userInput.isEmpty) return;

    setState(() {
      isLoading = true;
      messages.add({'role': 'user', 'text': userInput});
      _controller.clear();
    });

    _scrollToBottom();

    try {
      // ✅ Gọi API AI Suggest trước
      List<Rental> suggestedRentals = [];

      try {
        print('🔄 Calling getAdvancedSuggestions...');
        suggestedRentals = await AISuggestService.getAdvancedSuggestions(
          query: userInput,
        );
        print('✅ Advanced returned ${suggestedRentals.length} rentals');

        // ✅ DEBUG: Print rental list
        if (suggestedRentals.isNotEmpty) {
          print('📋 Rentals found:');
          for (var r in suggestedRentals) {
            print('  - ${r.title} (${r.price})');
          }
        }
      } catch (e) {
        print('⚠️ Advanced failed: $e');
        // Nếu advanced fails, thử basic suggest
        try {
          print('🔄 Calling getSuggestions (basic)...');
          suggestedRentals = await AISuggestService.getSuggestions(
            query: userInput,
            limit: 3,
          );
          print('✅ Basic returned ${suggestedRentals.length} rentals');
        } catch (e2) {
          print('❌ Basic also failed: $e2');
        }
      }

      print('🏠 Total suggested rentals: ${suggestedRentals.length}');

      // Tạo context từ các bài đăng tìm được
      String rentalContext = _buildRentalContext(suggestedRentals);

      // Gọi OpenAI
      await _callOpenAI(userInput, rentalContext, suggestedRentals);

      setState(() {
        isLoading = false;
      });
      _scrollToBottom();
    } catch (e) {
      print('❌ Error in sendMessage: $e');
      setState(() {
        isLoading = false;
        messages.add({
          'role': 'ai',
          'text': '❌ Đã xảy ra lỗi: ${e.toString()}'
        });
      });
      _scrollToBottom();
    }
  }

  String _buildRentalContext(List<Rental> rentals) {
    if (rentals.isEmpty) return '';

    StringBuffer context = StringBuffer();
    context.writeln('🏠 Dữ liệu bất động sản có sẵn:');

    for (int i = 0; i < rentals.length && i < 5; i++) {
      final rental = rentals[i];
      context.writeln('\n${i + 1}. ${rental.title}');
      context.writeln('   • Loại: ${rental.propertyType}');
      context.writeln('   • Giá: ${formatCurrency(rental.price)}/tháng');
      context.writeln('   • Diện tích: ${rental.area['total']}m²');
      context.writeln('   • Vị trí: ${rental.location['short']}');
      if (rental.amenities.isNotEmpty) {
        context.writeln('   • Tiện nghi: ${rental.amenities.take(3).join(', ')}');
      }
      if (rental.area['bedrooms'] != null) {
        context.writeln('   • Phòng ngủ: ${rental.area['bedrooms']}');
      }
    }

    return context.toString();
  }

  Future<void> _callOpenAI(String userInput, String rentalContext,
      List<Rental> suggestedRentals) async {
    try {
      final url = Uri.parse('https://api.openai.com/v1/chat/completions');

      String systemPrompt = '''Bạn là trợ lý AI chuyên về bất động sản tại Việt Nam, đặc biệt là khu vực Cần Thơ.

Nhiệm vụ:
1. Tư vấn và giải đáp câu hỏi về thuê nhà, mua nhà
2. Phân tích và đề xuất các lựa chọn phù hợp
3. Giải thích thuật ngữ bất động sản dễ hiểu
4. Đưa lời khuyên hữu ích

Hãy trả lời ngắn gọn (2-3 dòng), thân thiện và chuyên nghiệp. Sử dụng emoji phù hợp.
Nếu có bài đăng phù hợp, hãy giới thiệu chúng một cách tự nhiên và thuyết phục.''';

      String userMessage = userInput;

      if (rentalContext.isNotEmpty) {
        systemPrompt +=
        '\n\n📋 Dữ liệu bất động sản có sẵn để tham khảo (hãy đề xuất những bài phù hợp):';
        userMessage = '$rentalContext\n\n👤 Yêu cầu khách hàng: $userInput';
      }

      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${widget.apiKey}',
      };

      final body = jsonEncode({
        'model': 'gpt-4o-mini',
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': userMessage}
        ],
        'temperature': 0.7,
        'max_tokens': 300,
        'top_p': 0.9,
      });

      print('🤖 Calling OpenAI API...');
      final response = await http.post(url, headers: headers, body: body)
          .timeout(const Duration(seconds: 15));

      print('📊 OpenAI Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final result = jsonDecode(utf8.decode(response.bodyBytes));
        final aiReply = result['choices']?[0]?['message']?['content'] ??
            "🤖 Xin lỗi, tôi không thể tạo phản hồi lúc này.";

        print('✅ OpenAI response received');
        print('📝 AI Reply: $aiReply');

        setState(() {
          messages.add({'role': 'ai', 'text': aiReply.trim()});

          // ✅ Hiển thị thẻ gợi ý bài đăng
          if (suggestedRentals.isNotEmpty) {
            print('🏠 Adding ${suggestedRentals.length} rental cards...');

            // Header
            messages.add({
              'role': 'rental_header',
              'type': 'rental_header',
              'count': suggestedRentals.length,
            });

            // Cards
            for (var rental in suggestedRentals.take(3)) {
              messages.add({
                'role': 'rental_card',
                'type': 'rental_card',
                'rental': rental,
              });
              print('  ✅ Added card: ${rental.title}');
            }
          } else {
            print('⚠️ No rentals to display');
          }
        });
      } else {
        final errorBody = jsonDecode(response.body);
        String errorMessage = '❌ Lỗi API: ${response.statusCode}';

        if (errorBody['error'] != null) {
          errorMessage +=
          '\n${errorBody['error']['message'] ?? 'Unknown error'}';
        }

        print('❌ OpenAI Error: $errorMessage');

        setState(() {
          messages.add({'role': 'ai', 'text': errorMessage});
        });
      }
    } catch (e) {
      print('❌ OpenAI Exception: $e');
      setState(() {
        messages.add({
          'role': 'ai',
          'text': '❌ Lỗi kết nối: ${e.toString()}'
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.all(16),
        height: 800,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Image.asset(
                      "assets/img/chatbox.png",
                      width: 45,
                      height: 45,
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Trợ lý AI Bất Động Sản",
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          "Powered by OpenAI & Backend API",
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey[600]),
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
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                shrinkWrap: true,
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final msg = messages[index];
                  final isUser = msg['role'] == 'user';

                  // Header gợi ý
                  if (msg['type'] == 'rental_header') {
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 16, horizontal: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '🏠 Gợi Ý Bài Đăng Phù Hợp',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
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
                    );
                  }

                  // Rental Card
                  if (msg['type'] == 'rental_card' &&
                      msg['rental'] != null) {
                    final rentalData = msg['rental'] as Rental;
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 8),
                      child: _RentalSuggestionCard(
                        rental: rentalData,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  RentalDetailScreen(rental: rentalData),
                            ),
                          );
                        },
                      ),
                    );
                  }

                  // Text messages
                  return Container(
                    alignment:
                    isUser ? Alignment.centerRight : Alignment.centerLeft,
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
                },
              ),
            ),
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
                                  Colors.blue[700]!),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'AI đang xử lý...',
                            style: TextStyle(
                                color: Colors.grey[700], fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding:
              const EdgeInsets.symmetric(horizontal: 9.0, vertical: 10.0),
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
                        horizontal: 20, vertical: 14),
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
                            isLoading
                                ? Icons.hourglass_empty
                                : Icons.send,
                            color: Colors.white,
                            size: 20,
                          ),
                          onPressed: isLoading ? null : sendMessage,
                        ),
                      ),
                    ),
                  ),
                  onSubmitted: (_) =>
                  isLoading ? null : sendMessage(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============== RENTAL SUGGESTION CARD WIDGET ==============
class _RentalSuggestionCard extends StatelessWidget {
  final Rental rental;
  final VoidCallback? onTap;

  const _RentalSuggestionCard({
    required this.rental,
    this.onTap,
  });

  String formatCurrency(double amount) {
    final formatter = NumberFormat.currency(
        locale: 'vi_VN', symbol: '₫', decimalDigits: 0);
    return formatter.format(amount);
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = rental.images.isNotEmpty
        ? rental.images[0]
        : 'https://via.placeholder.com/300x200?text=No+Image';

    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ===== IMAGE SECTION =====
            Stack(
              children: [
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                    image: DecorationImage(
                      image: NetworkImage(imageUrl),
                      fit: BoxFit.cover,
                    ),
                    color: Colors.grey[300],
                  ),
                ),
                // Property Type Badge
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.blue[700],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      rental.propertyType,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                // Price Overlay
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withOpacity(0.7),
                          Colors.black.withOpacity(0.3),
                        ],
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                      ),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          formatCurrency(rental.price),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text(
                          '/tháng',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
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
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Location
                  Row(
                    children: [
                      Icon(Icons.location_on,
                          size: 14, color: Colors.blue[700]),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          rental.location['short'] ?? 'Chưa cập nhật',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Area & Rooms
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Icon(Icons.square_foot,
                                size: 14, color: Colors.orange[700]),
                            const SizedBox(width: 4),
                            Text(
                              '${rental.area['total'] ?? 0}m²',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[700],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (rental.area['bedrooms'] != null)
                        Expanded(
                          child: Row(
                            children: [
                              Icon(Icons.bed,
                                  size: 14, color: Colors.purple[700]),
                              const SizedBox(width: 4),
                              Text(
                                '${rental.area['bedrooms']} PN',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[700],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Amenities
                  if (rental.amenities.isNotEmpty)
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: rental.amenities
                          .take(3)
                          .map((amenity) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '✓ $amenity',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.blue[700],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ))
                          .toList(),
                    ),

                  const SizedBox(height: 12),

                  // Contact Info
                  if (rental.contactInfo != null)
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.person_outline,
                              size: 16, color: Colors.blue),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  rental.contactInfo!['name'] ?? 'Chủ nhà',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                  ),
                                ),
                                Text(
                                  rental.contactInfo!['phone'] ?? '',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.blue[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 12),

                  // View Details Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: onTap,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[700],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      child: const Text(
                        'Xem Chi Tiết',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
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
    );
  }
}