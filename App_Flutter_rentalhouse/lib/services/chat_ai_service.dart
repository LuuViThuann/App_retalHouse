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
  bool isLoading = false;
  List<Rental> rentals = [];

  @override
  void initState() {
    super.initState();
    loadRentals();

    messages.add({
      'role': 'ai',
      'text':
          '👋 Xin chào! Tôi là trợ lý AI của bạn. Hãy hỏi tôi về các bài đăng thuê nhà hoặc tìm kiếm nhà theo nhu cầu của bạn nhé!',
    });
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

  Future<void> sendMessage() async {
    final userInput = _controller.text.trim();
    if (userInput.isEmpty) return;

    setState(() {
      isLoading = true;
      messages.add({'role': 'user', 'text': userInput});
      _controller.clear();
    });

    final lowerInput = userInput.toLowerCase();
    List<Map<String, String>> newMessages = [];
    List<Rental> foundRentals = [];

    // 1. Tìm bài đăng theo loại hình bất động sản (propertyType)
    final matchedPropertyTypes = rentals
        .where(
            (rental) => lowerInput.contains(rental.propertyType.toLowerCase()))
        .map((e) => e.propertyType)
        .toSet()
        .toList();

    if (matchedPropertyTypes.isNotEmpty) {
      for (var type in matchedPropertyTypes) {
        final typeRentals = rentals
            .where((rental) =>
                rental.propertyType.toLowerCase() == type.toLowerCase())
            .toList();
        if (typeRentals.isNotEmpty) {
          foundRentals.addAll(typeRentals);
        }
      }
    }

    // 2. Tìm bài đăng theo từ khóa (tiêu đề, vị trí, tiện nghi)
    final matchingRentals = rentals
        .where((rental) =>
            rental.title.toLowerCase().contains(lowerInput) ||
            rental.location['short'].toLowerCase().contains(lowerInput) ||
            rental.amenities
                .any((amenity) => amenity.toLowerCase().contains(lowerInput)))
        .toList();
    if (matchingRentals.isNotEmpty) {
      foundRentals.addAll(matchingRentals);
    }

    // 3. Tìm nhà giá rẻ nhất
    if (lowerInput.contains('giá rẻ nhất')) {
      final cheapestRental = rentals
          .where((rental) => rental.price != null)
          .toList()
        ..sort((a, b) => a.price.compareTo(b.price));
      if (cheapestRental.isNotEmpty) {
        foundRentals.add(cheapestRental.first);
      }
    }

    // 4. Tìm nhà giá cao nhất
    if (lowerInput.contains('giá cao nhất') ||
        lowerInput.contains('đắt nhất')) {
      final mostExpensiveRental = rentals
          .where((rental) => rental.price != null)
          .toList()
        ..sort((a, b) => b.price.compareTo(a.price));
      if (mostExpensiveRental.isNotEmpty) {
        foundRentals.add(mostExpensiveRental.first);
      }
    }

    // 5. Tìm nhà theo diện tích
    if (lowerInput.contains('diện tích')) {
      final areaMatch = RegExp(r'\d+').firstMatch(lowerInput);
      if (areaMatch != null) {
        final targetArea = double.parse(areaMatch.group(0)!);
        final areaRentals = rentals
            .where((rental) => (rental.area['total'] - targetArea).abs() <= 10)
            .toList();
        if (areaRentals.isNotEmpty) {
          foundRentals.addAll(areaRentals);
        }
      }
    }

    // 6. Tìm nhà theo vị trí
    if (lowerInput.contains('vị trí') || lowerInput.contains('khu vực')) {
      final locationRentals = rentals
          .where((rental) =>
              rental.location['short'].toLowerCase().contains(lowerInput))
          .toList();
      if (locationRentals.isNotEmpty) {
        foundRentals.addAll(locationRentals);
      }
    }

    // Nếu có kết quả bài viết liên quan, hiển thị chi tiết các bài viết
    if (foundRentals.isNotEmpty) {
      setState(() {
        // Xóa trùng lặp bài viết
        final uniqueRentals =
            {for (var r in foundRentals) r.id: r}.values.toList();
        for (var rental in uniqueRentals) {
          messages.add({
            'role': 'ai',
            'text': '🏡 Gợi ý bài viết liên quan:',
            'type': 'rental',
            'rental': jsonEncode(rental.toJson()),
          });
        }
        isLoading = false;
      });
      return;
    }

    // Nếu không có kết quả, gọi API AI
    try {
      final url = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=${widget.apiKey}');
      final headers = {'Content-Type': 'application/json'};
      final body = jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': userInput}
            ]
          }
        ]
      });

      final responseApi = await http.post(url, headers: headers, body: body);

      if (responseApi.statusCode == 200) {
        final result = jsonDecode(responseApi.body);
        final aiReply = result['candidates']?[0]?['content']?['parts']?[0]
                ?['text'] ??
            "🤖 Không có phản hồi.";
        setState(() {
          messages.add({'role': 'ai', 'text': aiReply});
          isLoading = false;
        });
      } else {
        setState(() {
          messages.add(
              {'role': 'ai', 'text': '❌ Lỗi khi gọi AI: ${responseApi.body}'});
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        messages
            .add({'role': 'ai', 'text': '❌ Đã xảy ra lỗi: ${e.toString()}'});
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.all(16),
        height: 800,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Image.asset(
                  "assets/img/chatbox.png",
                  width: 45,
                  height: 45,
                ),
                const Text(
                  "Trợ lý AI tìm kiếm nhà thuê",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final msg = messages[index];
                  final isUser = msg['role'] == 'user';

                  if (msg['type'] == 'rental' && msg['rental'] != null) {
                    final rentalData =
                        Rental.fromJson(jsonDecode(msg['rental']!));
                    return RentalItemWidget(rental: rentalData);
                  }

                  return Container(
                    alignment:
                        isUser ? Alignment.centerRight : Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isUser ? Colors.blue[800] : Colors.grey[200],
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: isUser
                            ? [
                                BoxShadow(
                                  color: Colors.blue.withOpacity(0.3),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.2),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                      ),
                      child: Text(
                        msg['text'] ?? '',
                        style: TextStyle(
                          color: isUser ? Colors.white : Colors.black87,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  );
                },
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
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                    hintText: "Bạn muốn tìm nhà như thế nào?",
                    hintStyle: TextStyle(color: Colors.grey[600]),
                    border: InputBorder.none,
                    suffixIcon: Padding(
                      padding: const EdgeInsets.only(right: 10.0),
                      child: CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.blue,
                        child: IconButton(
                          icon: const Icon(Icons.send,
                              color: Colors.white, size: 20),
                          onPressed: sendMessage,
                        ),
                      ),
                    ),
                  ),
                  onSubmitted: (_) => sendMessage(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
