import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/config/api_routes.dart';
import 'package:flutter_rentalhouse/config/loading.dart';
import 'package:flutter_rentalhouse/viewmodels/vm_auth.dart';
import 'package:http/http.dart' as http;
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';

class NewAddressPage extends StatefulWidget {
  const NewAddressPage({super.key});

  @override
  State<NewAddressPage> createState() => _NewAddressPageState();
}

class _NewAddressPageState extends State<NewAddressPage> {
  final _formKey = GlobalKey<FormState>();
  final _streetController = TextEditingController();
  final _scrollController = ScrollController();

  bool isDefault = false;
  bool isLoading = false;

  List<dynamic> provinces = [];
  List<Map<String, dynamic>> districts = [];
  List<dynamic> wards = [];

  String? selectedProvince;
  String? selectedProvinceCode;
  String? selectedDistrict;
  String? _selectedDistrictCode; // fix bug cũ
  String? selectedWard;

  @override
  void initState() {
    super.initState();
    _fetchProvinces();
  }

  @override
  void dispose() {
    _streetController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchProvinces() async {
    setState(() => isLoading = true);
    try {
      final response = await http.get(ApiRoutes.provinces);
      if (response.statusCode == 200 && mounted) {
        setState(() {
          provinces = json.decode(utf8.decode(response.bodyBytes));
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted)
        _showSnackBar('Không tải được danh sách tỉnh/thành', Colors.red);
      setState(() => isLoading = false);
    }
  }

  Future<void> _fetchDistricts(String provinceCode) async {
    setState(() => isLoading = true);
    try {
      final response = await http.get(ApiRoutes.getDistricts(provinceCode));
      if (response.statusCode == 200 && mounted) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        setState(() {
          districts = List<Map<String, dynamic>>.from(data['districts'] ?? []);
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) _showSnackBar('Lỗi tải quận/huyện', Colors.red);
      setState(() => isLoading = false);
    }
  }

  Future<void> _fetchWards(String districtCode) async {
    setState(() => isLoading = true);
    try {
      final response = await http.get(ApiRoutes.getWards(districtCode));
      if (response.statusCode == 200 && mounted) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        setState(() {
          wards = List<dynamic>.from(data['wards'] ?? []);
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) _showSnackBar('Lỗi tải phường/xã', Colors.red);
      setState(() => isLoading = false);
    }
  }

  String _buildFullAddress() {
    final parts = [
      _streetController.text.trim(),
      selectedWard,
      selectedDistrict,
      selectedProvince,
      'Việt Nam',
    ];
    return parts.where((p) => p != null && p.isNotEmpty).join(', ');
  }

  String _buildDisplayAddress() {
    return '${_buildFullAddress()}${isDefault ? ' (Mặc định)' : ''}';
  }

  void _showSnackBar(String message, Color bg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(message),
          backgroundColor: bg,
          behavior: SnackBarBehavior.floating),
    );
  }

  bool get _canSubmit =>
      selectedProvince != null &&
      selectedDistrict != null &&
      selectedWard != null &&
      _streetController.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.blue[700],
        elevation: 0,
        title: Text(
          "Thêm địa chỉ ",
          style: const TextStyle(
              fontWeight: FontWeight.bold, color: Colors.white, fontSize: 19),
        ),
        leading: const BackButton(color: Colors.white),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
      ),
      body: Stack(
        children: [
          Form(
            key: _formKey,
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              children: [
                // Preview địa chỉ
                if (_buildFullAddress().isNotEmpty) ...[
                  Card(
                    elevation: 4,
                    shadowColor: Colors.red.withOpacity(0.15),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.red.shade50, Colors.white],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border:
                            Border.all(color: Colors.red.shade100, width: 1),
                      ),
                      child: Row(
                        children: [
                          // Cờ Việt Nam + icon location
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.asset(
                                'assets/img/iconVN.png',
                                width: 52,
                                height: 52,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),

                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Địa chỉ đầy đủ',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _buildFullAddress(),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                // Tag Việt Nam đẹp
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.red.withOpacity(0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.location_on,
                                          color: Colors.white, size: 16),
                                      SizedBox(width: 6),
                                      Text(
                                        'Việt Nam',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                _buildSelectorCard(
                  title: 'Tỉnh/Thành phố',
                  value: selectedProvince ?? 'Chọn tỉnh/thành',
                  icon: Icons.location_city,
                  onTap: () => _selectProvince(context),
                  isSelected: selectedProvince != null,
                ),
                const SizedBox(height: 12),

                _buildSelectorCard(
                  title: 'Quận/Huyện',
                  value: selectedDistrict ?? 'Chọn quận/huyện',
                  icon: Icons.location_city_outlined,
                  onTap: selectedProvince == null
                      ? null
                      : () => _selectDistrict(context),
                  isSelected: selectedDistrict != null,
                ),
                const SizedBox(height: 12),

                _buildSelectorCard(
                  title: 'Phường/Xã',
                  value: selectedWard ?? 'Chọn phường/xã',
                  icon: Icons.home_work_outlined,
                  onTap: selectedDistrict == null
                      ? null
                      : () => _selectWard(context),
                  isSelected: selectedWard != null,
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _streetController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: 'Số nhà, tên đường, tòa nhà *',
                    prefixIcon: const Icon(Icons.home_outlined),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                  validator: (v) => v?.trim().isEmpty ?? true
                      ? 'Vui lòng nhập số nhà/tên đường'
                      : null,
                ),

                const SizedBox(height: 24),

                // Switch mặc định
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(30),
                    onTap: () => setState(() => isDefault = !isDefault),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 16),
                      decoration: BoxDecoration(
                        gradient: isDefault
                            ? LinearGradient(
                                colors: [
                                  Colors.amber.shade600,
                                  Colors.orange.shade700
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : LinearGradient(colors: [
                                Colors.grey.shade200,
                                Colors.grey.shade300
                              ]),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: isDefault
                                ? Colors.amber.withOpacity(0.4)
                                : Colors.transparent,
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          AnimatedScale(
                            scale: isDefault ? 1.2 : 1.0,
                            duration: const Duration(milliseconds: 300),
                            child: Icon(
                              isDefault ? Icons.home : Icons.home_outlined,
                              color: isDefault
                                  ? Colors.white
                                  : Colors.grey.shade600,
                              size: 32,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Đặt làm địa chỉ mặc định',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: isDefault
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                ),
                                Text(
                                  isDefault
                                      ? 'Địa chỉ này sẽ được ưu tiên khi đặt phòng'
                                      : 'Bật để sử dụng làm địa chỉ chính',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDefault
                                        ? Colors.white70
                                        : Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: isDefault
                                ? const Icon(Icons.check_circle,
                                    color: Colors.white, key: ValueKey(true))
                                : const Icon(Icons.radio_button_unchecked,
                                    color: Colors.grey, key: ValueKey(false)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 32),
                // Nút xác nhận đẹp
                ElevatedButton(
                  onPressed: isLoading || !_canSubmit
                      ? null
                      : () async {
                          if (!_formKey.currentState!.validate()) return;

                          setState(() => isLoading = true);
                          final fullAddress = _buildFullAddress();

                          try {
                            final authVM = Provider.of<AuthViewModel>(context,
                                listen: false);
                            await authVM.updateUserProfile(
                              phoneNumber:
                                  authVM.currentUser?.phoneNumber ?? '',
                              address: fullAddress,
                              username: authVM.currentUser?.username ?? '',
                            );

                            if (mounted) {
                              if (authVM.errorMessage == null) {
                                _showSnackBar('Địa chỉ đã được lưu thành công!',
                                    Colors.green);
                                Navigator.pop(context, fullAddress);
                              } else {
                                _showSnackBar(authVM.errorMessage!, Colors.red);
                              }
                            }
                          } catch (e) {
                            _showSnackBar('Lỗi lưu địa chỉ: $e', Colors.red);
                          } finally {
                            if (mounted) setState(() => isLoading = false);
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: 8,
                    shadowColor: Colors.blue[700]!.withOpacity(0.4),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          height: 28,
                          width: 28,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 3),
                        )
                      : const Text(
                          'HOÀN THÀNH & LƯU',
                          style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5),
                        ),
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectorCard({
    required String title,
    required String value,
    required IconData icon,
    required VoidCallback? onTap,
    required bool isSelected,
  }) {
    return Card(
      color: Colors.white,
      elevation: isSelected ? 6 : 2,
      shadowColor: isSelected
          ? Colors.blue.withOpacity(0.18)
          : Colors.black.withOpacity(0.08),
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isSelected
            ? const BorderSide(color: Colors.blue, width: 1.5)
            : BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              // Icon tròn nổi bật
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.blue[700] : Colors.grey.shade200,
                  shape: BoxShape.circle,
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                              color: Colors.blue.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 3))
                        ]
                      : null,
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 22,
                ),
              ),

              const SizedBox(width: 16),

              // Nội dung
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.blue[800] : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),

              // Trailing icon mượt mà
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  isSelected
                      ? Icons.check_circle_rounded
                      : Icons.chevron_right_rounded,
                  key: ValueKey(isSelected),
                  color: isSelected ? Colors.blue[700] : Colors.grey.shade400,
                  size: 26,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectProvince(BuildContext ctx) async {
    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _BottomSheetSelector(title: 'Chọn Tỉnh/Thành phố', items: provinces),
    );

    if (selected != null && mounted) {
      setState(() {
        selectedProvince = selected['name'];
        selectedProvinceCode = selected['code'].toString();
        selectedDistrict = null;
        _selectedDistrictCode = null;
        selectedWard = null;
        districts.clear();
        wards.clear();
      });
      await _fetchDistricts(selectedProvinceCode!);
      _scrollController.animateTo(0,
          duration: const Duration(milliseconds: 300), curve: Curves.ease);
    }
  }

  Future<void> _selectDistrict(BuildContext ctx) async {
    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BottomSheetSelector(
          title: 'Chọn Quận/Huyện', items: districts, displayKey: 'name'),
    );

    if (selected != null && mounted) {
      setState(() {
        selectedDistrict = selected['name'];
        _selectedDistrictCode = selected['code'].toString();
        selectedWard = null;
        wards.clear();
      });
      await _fetchWards(_selectedDistrictCode!);
    }
  }

  Future<void> _selectWard(BuildContext ctx) async {
    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BottomSheetSelector(
          title: 'Chọn Phường/Xã', items: wards, displayKey: 'name'),
    );

    if (selected != null && mounted) {
      setState(() => selectedWard = selected['name']);
    }
  }
}

// Widget chọn chung đẹp
class _BottomSheetSelector extends StatelessWidget {
  final String title;
  final List items;
  final String displayKey;

  const _BottomSheetSelector(
      {required this.title, required this.items, this.displayKey = 'name'});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      height: MediaQuery.of(context).size.height * 0.8,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Huỷ')),
                Text(title,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(width: 48),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: items.length,
              itemBuilder: (_, i) {
                final item = items[i];
                final displayText = item is Map
                    ? item[displayKey] ?? item['name'] ?? ''
                    : item.toString();
                return ListTile(
                  title:
                      Text(displayText, style: const TextStyle(fontSize: 16)),
                  onTap: () => Navigator.pop(context, item),
                  trailing: const Icon(Icons.check, color: Colors.transparent),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
