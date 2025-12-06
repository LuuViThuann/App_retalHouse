import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:flutter_rentalhouse/models/rental.dart';
import 'package:flutter_rentalhouse/services/rental_service.dart';
import 'package:flutter_rentalhouse/views/main_list_cart_home.dart';

class ChatAIBottomSheet extends StatefulWidget {
  final String apiKey;

  const ChatAIBottomSheet({super.key, required this.apiKey});

  @override
  State<ChatAIBottomSheet> createState() => _ChatAIBottomSheetState();
}

class _ChatAIBottomSheetState extends State<ChatAIBottomSheet> {
  List<Map<String, String>> messages = [];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool isLoading = false;
  List<Rental> rentals = [];

  @override
  void initState() {
    super.initState();
    loadRentals();

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

  Future<void> loadRentals() async {
    try {
      final rentalService = RentalService();
      final rentalData = await rentalService.fetchRentals();
      setState(() {
        rentals = rentalData;
      });
    } catch (e) {
      debugPrint('Lỗi khi load bài đăng thuê nhà: $e');
    }
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
    if (userInput.isEmpty) return;

    setState(() {
      isLoading = true;
      messages.add({'role': 'user', 'text': userInput});
      _controller.clear();
    });

    _scrollToBottom();

    final lowerInput = userInput.toLowerCase();
    List<Rental> foundRentals = [];

    // 1. Tìm bài đăng theo loại hình bất động sản
    final matchedPropertyTypes = rentals
        .where((rental) => lowerInput.contains(rental.propertyType.toLowerCase()))
        .map((e) => e.propertyType)
        .toSet()
        .toList();

    if (matchedPropertyTypes.isNotEmpty) {
      for (var type in matchedPropertyTypes) {
        final typeRentals = rentals
            .where((rental) => rental.propertyType.toLowerCase() == type.toLowerCase())
            .toList();
        if (typeRentals.isNotEmpty) {
          foundRentals.addAll(typeRentals);
        }
      }
    }

    // 2. Tìm bài đăng theo từ khóa
    final matchingRentals = rentals
        .where((rental) =>
    rental.title.toLowerCase().contains(lowerInput) ||
        rental.location['short'].toLowerCase().contains(lowerInput) ||
        rental.amenities.any((amenity) => amenity.toLowerCase().contains(lowerInput)))
        .toList();
    if (matchingRentals.isNotEmpty) {
      foundRentals.addAll(matchingRentals);
    }

    // 3. Tìm nhà giá rẻ nhất
    if (lowerInput.contains('giá rẻ') || lowerInput.contains('rẻ nhất')) {
      final cheapestRental = rentals
          .where((rental) => rental.price != null)
          .toList()
        ..sort((a, b) => a.price.compareTo(b.price));
      if (cheapestRental.isNotEmpty) {
        foundRentals.add(cheapestRental.first);
      }
    }

    // 4. Tìm nhà giá cao nhất
    if (lowerInput.contains('giá cao') || lowerInput.contains('đắt nhất')) {
      final mostExpensiveRental = rentals
          .where((rental) => rental.price != null)
          .toList()
        ..sort((a, b) => b.price.compareTo(a.price));
      if (mostExpensiveRental.isNotEmpty) {
        foundRentals.add(mostExpensiveRental.first);
      }
    }

    // 5. Tìm nhà theo diện tích
    if (lowerInput.contains('diện tích') || lowerInput.contains('m2')) {
      final areaMatch = RegExp(r'\d+').firstMatch(lowerInput);
      if (areaMatch != null) {
        final targetArea = double.parse(areaMatch.group(0)!);
        final areaRentals = rentals
            .where((rental) => (rental.area['total'] - targetArea).abs() <= 15)
            .toList();
        if (areaRentals.isNotEmpty) {
          foundRentals.addAll(areaRentals);
        }
      }
    }

    // 6. Tìm nhà theo vị trí
    if (lowerInput.contains('vị trí') || lowerInput.contains('khu vực') || lowerInput.contains('gần')) {
      final locationRentals = rentals
          .where((rental) => rental.location['short'].toLowerCase().contains(lowerInput))
          .toList();
      if (locationRentals.isNotEmpty) {
        foundRentals.addAll(locationRentals);
      }
    }

    // Nếu có kết quả bài viết liên quan
    if (foundRentals.isNotEmpty) {
      // Xóa trùng lặp
      final uniqueRentals = {for (var r in foundRentals) r.id: r}.values.toList();

      // Tạo context về các bài đăng tìm được
      String rentalContext = _buildRentalContext(uniqueRentals);

      // Gọi OpenAI để tạo phản hồi tự nhiên
      await _callOpenAI(userInput, rentalContext, uniqueRentals);

      setState(() {
        isLoading = false;
      });
      _scrollToBottom();
      return;
    }

    // Nếu không có kết quả từ database, gọi AI để tư vấn chung
    await _callOpenAI(userInput, null, []);

    setState(() {
      isLoading = false;
    });
    _scrollToBottom();
  }

  String _buildRentalContext(List<Rental> rentals) {
    if (rentals.isEmpty) return '';

    StringBuffer context = StringBuffer();
    context.writeln('Dữ liệu bất động sản có sẵn:');

    for (int i = 0; i < rentals.length && i < 5; i++) {
      final rental = rentals[i];
      context.writeln('\n${i + 1}. ${rental.title}');
      context.writeln('   - Loại: ${rental.propertyType}');
      context.writeln('   - Giá: ${formatCurrency(rental.price)}/tháng');
      context.writeln('   - Diện tích: ${rental.area['total']}m²');
      context.writeln('   - Vị trí: ${rental.location['short']}');
      if (rental.amenities.isNotEmpty) {
        context.writeln('   - Tiện nghi: ${rental.amenities.take(3).join(', ')}');
      }
    }

    return context.toString();
  }

  Future<void> _callOpenAI(String userInput, String? rentalContext, List<Rental> foundRentals) async {
    try {
      final url = Uri.parse('https://api.openai.com/v1/chat/completions');

      // System prompt cho AI assistant chuyên về bất động sản
      String systemPrompt = '''Bạn là trợ lý AI chuyên về bất động sản tại Việt Nam, đặc biệt là khu vực Cần Thơ. 
    Nhiệm vụ của bạn là:
    1. Tư vấn và giải đáp các câu hỏi về thuê nhà, mua nhà
    2. Phân tích và đề xuất các lựa chọn phù hợp với nhu cầu của khách hàng
    3. Giải thích các thuật ngữ bất động sản một cách dễ hiểu
    4. Đưa ra lời khuyên hữu ích về vị trí, giá cả, tiện nghi

    Hãy trả lời ngắn gọn, thân thiện và chuyên nghiệp. Sử dụng emoji phù hợp để làm cho cuộc trò chuyện sinh động hơn.''';

      String userMessage = userInput;

      if (rentalContext != null && rentalContext.isNotEmpty) {
        systemPrompt += '\n\nHãy phân tích và giới thiệu các bất động sản phù hợp từ dữ liệu dưới đây:';
        userMessage = '$rentalContext\n\nYêu cầu của khách hàng: $userInput';
      }

      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${widget.apiKey}',
      };

      final body = jsonEncode({
        'model': 'gpt-4o-mini', // Model phù hợp: nhanh, rẻ, và đủ thông minh cho chatbot
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': userMessage}
        ],
        'temperature': 0.7,
        'max_tokens': 500,
        'top_p': 0.9,
      });

      final response = await http.post(url, headers: headers, body: body);

      if (response.statusCode == 200) {
        final result = jsonDecode(utf8.decode(response.bodyBytes));
        final aiReply = result['choices']?[0]?['message']?['content'] ??
            "🤖 Xin lỗi, tôi không thể tạo phản hồi lúc này.";

        setState(() {
          messages.add({'role': 'ai', 'text': aiReply.trim()});

          // Nếu có bài đăng liên quan, thêm vào sau phản hồi của AI
          if (foundRentals.isNotEmpty) {
            final uniqueRentals = {for (var r in foundRentals) r.id: r}.values.toList();
            for (var rental in uniqueRentals.take(3)) {
              messages.add({
                'role': 'ai',
                'text': '',
                'type': 'rental',
                'rental': jsonEncode(rental.toJson()),
              });
            }
          }
        });
      } else {
        final errorBody = jsonDecode(response.body);
        String errorMessage = '❌ Lỗi API: ${response.statusCode}';

        if (errorBody['error'] != null) {
          errorMessage += '\n${errorBody['error']['message'] ?? 'Unknown error'}';
        }

        setState(() {
          messages.add({'role': 'ai', 'text': errorMessage});
        });
      }
    } catch (e) {
      setState(() {
        messages.add({
          'role': 'ai',
          'text': '❌ Đã xảy ra lỗi khi kết nối với AI:\n${e.toString()}'
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
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
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          "Powered by OpenAI",
                          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
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

                  if (msg['type'] == 'rental' && msg['rental'] != null) {
                    final rentalData = Rental.fromJson(jsonDecode(msg['rental']!));
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: RentalItemWidget(rental: rentalData),
                    );
                  }

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
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[700]!),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'AI đang suy nghĩ...',
                            style: TextStyle(color: Colors.grey[700], fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 9.0, vertical: 10.0),
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
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    hintText: "Tôi cần tìm nhà...",
                    hintStyle: TextStyle(color: Colors.grey[500]),
                    border: InputBorder.none,
                    suffixIcon: Padding(
                      padding: const EdgeInsets.only(right: 10.0),
                      child: CircleAvatar(
                        radius: 18,
                        backgroundColor: isLoading ? Colors.grey : Colors.blue[700],
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