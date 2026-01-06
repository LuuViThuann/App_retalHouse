import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/config/loading.dart';
import 'package:flutter_rentalhouse/constants/app_color.dart';
import 'package:flutter_rentalhouse/models/rental.dart';
import 'package:flutter_rentalhouse/viewmodels/vm_auth.dart';
import 'package:flutter_rentalhouse/viewmodels/vm_chat.dart';
import 'package:flutter_rentalhouse/views/chat_user.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:lottie/lottie.dart';

class DetailsTab extends StatelessWidget {
  final Rental rental;
  final String Function(double) formatCurrency;

  const DetailsTab({
    super.key,
    required this.rental,
    required this.formatCurrency,
  });

  bool _isMyPost(BuildContext context) {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    return authViewModel.currentUser?.id == rental.userId;
  }

  String _formatDeposit(dynamic deposit) {
    if (deposit == null) return formatCurrency(0.0);
    double? depositValue;
    if (deposit is num) {
      depositValue = deposit.toDouble();
    } else if (deposit is String) {
      final trimmed = deposit.trim().replaceAll(',', '.');
      depositValue = double.tryParse(trimmed);
    }
    if (depositValue == null || depositValue < 0) return formatCurrency(0.0);
    return formatCurrency(depositValue);
  }

  Widget _buildPhoneCallRow({
    required String phone,
    required BuildContext context,
  }) {
    final cleanPhone = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');

    return Row(
      children: [
        // Phần gọi điện
        Expanded(
          child: InkWell(
            onTap: () {
              final Uri telUri = Uri(scheme: 'tel', path: cleanPhone);
              launchUrl(telUri).catchError((e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Không thể mở ứng dụng gọi: $e')),
                );
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primaryColorIconDetail.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primaryColorIconDetail.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primaryColorIconDetail.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.phone,
                      color: AppColors.primaryColorIconDetail,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Số điện thoại',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.secondaryTextColorIconDetail,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          phone,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryColorIconDetail,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Nút Gọi ngay + Nhắn tin
        Column(
          children: [
            ElevatedButton.icon(
              onPressed: () {
                final Uri telUri = Uri(scheme: 'tel', path: cleanPhone);
                launchUrl(telUri).catchError((e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Không thể gọi: $e')),
                  );
                });
              },
              icon: const Icon(Icons.phone_in_talk, size: 20),
              label: const Text('Gọi ngay'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
            ),
            const SizedBox(height: 8),
            _buildMessageButton(context),
          ],
        ),
      ],
    );
  }

  Widget _buildMessageButton(BuildContext context) {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    final chatViewModel = Provider.of<ChatViewModel>(context, listen: false);

    return GestureDetector(
      onTap: () async {
        if (authViewModel.currentUser == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Vui lòng đăng nhập để nhắn tin!'),
              backgroundColor: Colors.redAccent,
            ),
          );
          return;
        }

        if (rental.id == null || rental.userId.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Thông tin bài đăng không hợp lệ!'),
              backgroundColor: Colors.redAccent,
            ),
          );
          return;
        }

        try {
          // Hiển thị loading
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => Dialog(
              backgroundColor: Colors.transparent,
              child: SizedBox(
                height: 140,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Lottie.asset(
                      AssetsConfig.loadingLottie, // ← đảm bảo import đúng
                      width: 100,
                      height: 100,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Đang mở cuộc trò chuyện...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );

          final conversation = await chatViewModel.getOrCreateConversation(
            rentalId: rental.id!,
            landlordId: rental.userId,
            token: authViewModel.currentUser!.token!,
          );

          if (conversation == null) {
            throw Exception('Không thể tạo hoặc lấy cuộc trò chuyện');
          }

          await chatViewModel.fetchConversations(authViewModel.currentUser!.token!);

          Navigator.of(context).pop(); // đóng loading

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatScreen(
                rentalId: rental.id!,
                landlordId: rental.userId,
                conversationId: conversation.id,
              ),
            ),
          );
        } catch (e) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lỗi khi mở cuộc trò chuyện: $e'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.primaryColorIconDetail,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.message_rounded, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text(
              'Nhắn tin',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasPhone = rental.contactInfo['phone'] != null &&
        rental.contactInfo['phone'].toString().trim().isNotEmpty;

    final isMyPost = _isMyPost(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Thông tin liên hệ (đã bổ sung nút nhắn tin)
        _buildCard(
          title: 'Thông tin liên hệ',
          icon: Icons.contact_phone,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildContactRow(
                      rental.contactInfo['name'] ?? 'Chủ nhà',
                      Icons.person,
                    ),
                  ),
                  Expanded(
                    child: _buildContactRow(
                      rental.contactInfo['availableHours'] ?? 'Không xác định',
                      Icons.access_time,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Chỉ hiển thị phần liên lạc nếu KHÔNG phải bài của mình
              if (!isMyPost) ...[
                if (hasPhone)
                  _buildPhoneCallRow(
                    phone: rental.contactInfo['phone'].toString().trim(),
                    context: context,
                  )
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: _buildContactRow(
                      'Không có số điện thoại',
                      Icons.phone_disabled,
                    ),
                  ),

                // Nút nhắn tin
                if (!hasPhone) ...[
                  const SizedBox(height: 12),
                  _buildMessageButton(context),
                ]
                // Nếu có phone thì nút nhắn tin nằm trong _buildPhoneCallRow
              ]
              // Nếu là bài của mình → có thể hiển thị thông báo nhẹ (tuỳ chọn)
              else
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: Text(
                      'Đây là bài đăng của bạn',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontStyle: FontStyle.italic,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildCard(
          title: 'Diện tích',
          icon: Icons.square_foot,
          child: Column(
            children: [
              // Tổng diện tích
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primaryColorIconDetail.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.home, color: AppColors.primaryColorIconDetail, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tổng diện tích',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.secondaryTextColorIconDetail,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${rental.area['total']} m²',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textColorIconDetail,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Chi tiết các phòng
              Row(
                children: [
                  Expanded(
                    child: _buildAreaItem(
                      'Phòng khách',
                      '${rental.area['livingRoom']} m²',
                      Icons.living,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildAreaItem(
                      'Phòng ngủ',
                      '${rental.area['bedrooms']} m²',
                      Icons.bed,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildAreaItem(
                      'Nhà vệ sinh',
                      '${rental.area['bathrooms']} m²',
                      Icons.bathroom,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(child: SizedBox()),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Nội thất & Tiện ích
        _buildCard(
          title: 'Nội thất & Tiện ích',
          icon: Icons.chair,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...rental.furniture.map((item) => _buildFeatureChip(item)),
              ...rental.amenities.map((item) => _buildFeatureChip(item)),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Kết nối & Môi trường
        _buildCard(
          title: 'Môi trường xung quanh',
          icon: Icons.place,
          child: Column(
            children: rental.surroundings.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              return Padding(
                padding: EdgeInsets.only(bottom: index < rental.surroundings.length - 1 ? 12 : 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: AppColors.primaryColorIconDetail,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        item,
                        style: TextStyle(
                          fontSize: 15,
                          color: AppColors.textColorIconDetail,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 16),

        // Điều khoản thuê
        _buildCard(
          title: 'Điều khoản thuê',
          icon: Icons.description,
          child: Column(
            children: [
              _buildTermRow(
                'Thời hạn tối thiểu',
                rental.rentalTerms['minimumLease'] ?? 'Không xác định',
                Icons.calendar_today,
              ),
              const Divider(height: 24),
              _buildTermRow(
                'Tiền cọc',
                _formatDeposit(rental.rentalTerms['deposit']),
                Icons.account_balance_wallet,
              ),
              const Divider(height: 24),
              _buildTermRow(
                'Thanh toán',
                rental.rentalTerms['paymentMethod'] ?? 'Không xác định',
                Icons.payment,
              ),
              const Divider(height: 24),
              _buildTermRow(
                'Gia hạn hợp đồng',
                rental.rentalTerms['renewalTerms'] ?? 'Không xác định',
                Icons.autorenew,
              ),
            ],
          ),
        ),



        // Thông tin liên hệ


        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primaryColorIconDetail, size: 22),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textColorIconDetail,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildAreaItem(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.secondaryTextColorIconDetail, size: 22),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.secondaryTextColorIconDetail,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.textColorIconDetail,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primaryColorIconDetail.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primaryColorIconDetail.withOpacity(0.2)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          color: AppColors.textColorIconDetail,
        ),
      ),
    );
  }

  Widget _buildTermRow(String label, String value, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.primaryColorIconDetail, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.secondaryTextColorIconDetail,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.textColorIconDetail,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildContactRow(String value, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.primaryColorIconDetail.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.primaryColorIconDetail, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              color: AppColors.textColorIconDetail,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}