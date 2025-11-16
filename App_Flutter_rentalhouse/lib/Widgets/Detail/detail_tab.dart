import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/Widgets/Detail/detail_row.dart';
import 'package:flutter_rentalhouse/Widgets/Detail/detail_section.dart';
import 'package:flutter_rentalhouse/models/rental.dart';
import 'package:flutter_rentalhouse/widgets/section_title.dart';

class DetailsTab extends StatelessWidget {
  final Rental rental;
  final String Function(double) formatCurrency;

  const DetailsTab(
      {super.key, required this.rental, required this.formatCurrency});

  // Helper method to safely parse and format deposit
  String _formatDeposit(dynamic deposit) {
    if (deposit == null) {
      return formatCurrency(0.0);
    }

    double? depositValue;
    if (deposit is num) {
      depositValue = deposit.toDouble();
    } else if (deposit is String) {
      final trimmed = deposit.trim().replaceAll(',', '.');
      depositValue = double.tryParse(trimmed);
    }

    if (depositValue == null || depositValue < 0) {
      return formatCurrency(0.0);
    }

    return formatCurrency(depositValue);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.all(20.0),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.blue.shade50, Colors.white],
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.shade100.withOpacity(0.2),
                blurRadius: 10,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(color: Colors.blue.shade100.withOpacity(0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DetailRow(
                icon: Icons.square_foot,
                label: 'Diện tích',
                value:
                    '${rental.area['total']} m² (Phòng khách ${rental.area['livingRoom']} m², 2PN ~${rental.area['bedrooms']} m², 2WC ~${rental.area['bathrooms']} m²)',
              ),
              const SizedBox(height: 20),
              DetailSection(
                title: 'Nội thất & Tiện ích',
                icon: Icons.chair,
                items: [
                  ...rental.furniture.map((item) => '• $item'),
                  ...rental.amenities.map((item) => '• $item'),
                ],
              ),
              const SizedBox(height: 20),
              DetailSection(
                title: 'Kết nối & Môi trường xung quanh',
                icon: Icons.place,
                items: rental.surroundings.map((item) => '• $item').toList(),
              ),
              const SizedBox(height: 20),
              DetailSection(
                title: 'Điều khoản thuê',
                icon: Icons.description,
                items: [
                  'Thời hạn thuê tối thiểu: ${rental.rentalTerms['minimumLease'] ?? 'Không xác định'}',
                  'Cọc: ${_formatDeposit(rental.rentalTerms['deposit'])}',
                  'Thanh toán: ${rental.rentalTerms['paymentMethod'] ?? 'Không xác định'}',
                  'Gia hạn hợp đồng: ${rental.rentalTerms['renewalTerms'] ?? 'Không xác định'}',
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const SectionTitle('Thông tin liên hệ'),
        Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.all(20.0),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.blue.shade50, Colors.white],
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.shade100.withOpacity(0.2),
                blurRadius: 10,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(color: Colors.blue.shade100.withOpacity(0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DetailRow(
                icon: Icons.person,
                label: 'Chủ nhà',
                value: rental.contactInfo['name'] ?? 'Chủ nhà',
              ),
              const SizedBox(height: 12),
              DetailRow(
                icon: Icons.phone,
                label: 'SĐT/Zalo',
                value: rental.contactInfo['phone'] ?? 'Không có số điện thoại',
              ),
              const SizedBox(height: 12),
              DetailRow(
                icon: Icons.access_time,
                label: 'Giờ liên hệ',
                value: rental.contactInfo['availableHours'] ?? 'Không xác định',
              ),
            ],
          ),
        ),
      ],
    );
  }
}
