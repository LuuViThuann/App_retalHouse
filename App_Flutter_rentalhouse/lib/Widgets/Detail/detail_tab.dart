import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/Widgets/Detail/detail_row.dart';
import 'package:flutter_rentalhouse/Widgets/Detail/detail_section.dart';
import 'package:flutter_rentalhouse/models/rental.dart';
import 'package:flutter_rentalhouse/widgets/section_title.dart';


class DetailsTab extends StatelessWidget {
  final Rental rental;
  final String Function(double) formatCurrency;

  const DetailsTab({super.key, required this.rental, required this.formatCurrency});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('Thông tin chi tiết:'),
        Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, Colors.grey[50]!],
            ),
            borderRadius: BorderRadius.circular(20),
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
              const SizedBox(height: 16),
              DetailSection(
                title: 'Nội thất & Tiện ích',
                icon: Icons.chair,
                items: [
                  ...rental.furniture.map((item) => '• $item'),
                  ...rental.amenities.map((item) => '• $item'),
                ],
              ),
              const SizedBox(height: 16),
              DetailSection(
                title: 'Kết nối & Môi trường xung quanh',
                icon: Icons.place,
                items: rental.surroundings.map((item) => '• $item').toList(),
              ),
              const SizedBox(height: 16),
              DetailSection(
                title: 'Điều khoản thuê',
                icon: Icons.description,
                items: [
                  'Thời hạn thuê tối thiểu: ${rental.rentalTerms['minimumLease']}',
                  'Cọc: ${formatCurrency(double.parse(rental.rentalTerms['deposit']))}',
                  'Thanh toán: ${rental.rentalTerms['paymentMethod']}',
                  'Gia hạn hợp đồng: ${rental.rentalTerms['renewalTerms']}',
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const SectionTitle('Thông tin liên hệ'),
        Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, Colors.grey[50]!],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DetailRow(
                icon: Icons.person,
                label: 'Chủ nhà',
                value: rental.contactInfo['name'] ?? 'Chủ nhà',
              ),
              const SizedBox(height: 8),
              DetailRow(
                icon: Icons.phone,
                label: 'SĐT/Zalo',
                value: rental.contactInfo['phone'] ?? 'Không có số điện thoại',
              ),
              const SizedBox(height: 8),
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