import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/config/api_routes.dart';
import 'package:flutter_rentalhouse/viewmodels/vm_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';

class NewAddressPage extends StatefulWidget {
  const NewAddressPage({super.key});

  @override
  State<NewAddressPage> createState() => _NewAddressPageState();
}

class _NewAddressPageState extends State<NewAddressPage> {
  final _formKey = GlobalKey<FormState>();
  final _streetController = TextEditingController();
  bool isDefault = false;

  List<dynamic> provinces = [];
  List<Map<String, dynamic>> districts = [];
  List<dynamic> wards = [];

  String? selectedProvinceCode;
  String? selectedProvince;
  String? selectedDistrict;
  String? selectedWard;

  bool isLoading = false;

  @override
  void dispose() {
    _streetController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _fetchProvinces();
  }

  Future<void> _fetchProvinces() async {
    setState(() => isLoading = true);
    try {
      final response = await http.get(ApiRoutes.provinces);
      if (response.statusCode == 200) {
        setState(() {
          provinces = json.decode(
              utf8.decode(response.bodyBytes)); // API trả mảng trực tiếp
          isLoading = false;
        });
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể tải dữ liệu tỉnh: $e')),
        );
      }
    }
  }

  Future<void> _fetchDistricts(String provinceCode) async {
    setState(() {
      isLoading = true;
      districts.clear();
      selectedDistrict = null;
      selectedWard = null;
    });

    try {
      final response = await http.get(ApiRoutes.getDistricts(provinceCode));
      if (response.statusCode == 200) {
        final Map<String, dynamic> data =
            json.decode(utf8.decode(response.bodyBytes));
        setState(() {
          districts = List<Map<String, dynamic>>.from(
              data['districts'] ?? []); // Lấy từ nested 'districts'
          isLoading = false;
        });
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi tải huyện: $e')),
        );
      }
    }
  }

  Future<void> _fetchWards(String districtCode) async {
    setState(() {
      isLoading = true;
      wards.clear();
      selectedWard = null;
    });
    try {
      final response = await http.get(ApiRoutes.getWards(districtCode));
      if (response.statusCode == 200) {
        final Map<String, dynamic> data =
            json.decode(utf8.decode(response.bodyBytes));
        setState(() {
          wards =
              List<dynamic>.from(data['wards'] ?? []); // Lấy từ nested 'wards'
          isLoading = false;
        });
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể tải dữ liệu xã: $e')),
        );
      }
    }
  }

  String _formatAddress() {
    final parts = [
      _streetController.text.trim(),
      selectedWard,
      selectedDistrict,
      selectedProvince,
      'Việt Nam',
      if (isDefault) '(Mặc định)',
    ];
    return parts.where((part) => part != null && part.isNotEmpty).join(', ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('Nhập địa chỉ mới'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildCitySelector(),
            const SizedBox(height: 12),
            _buildDistrictSelector(),
            const SizedBox(height: 12),
            _buildWardSelector(),
            const SizedBox(height: 12),
            _buildTextField('Tên đường, Tòa nhà, Số nhà *'),
            const SizedBox(height: 24),
            _buildDefaultSwitch(),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (_formKey.currentState!.validate()) {
                        if (selectedProvince == null ||
                            selectedDistrict == null ||
                            selectedWard == null ||
                            _streetController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'Vui lòng điền đầy đủ thông tin địa chỉ')),
                          );
                          return;
                        }

                        final address = _formatAddress();
                        final authViewModel =
                            Provider.of<AuthViewModel>(context, listen: false);

                        try {
                          await authViewModel.updateUserProfile(
                            phoneNumber:
                                authViewModel.currentUser?.phoneNumber ?? '',
                            address: address,
                            username: authViewModel.currentUser?.username ?? '',
                          );

                          if (authViewModel.errorMessage == null) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content:
                                      Text('Địa chỉ đã được lưu thành công!'),
                                  backgroundColor: Colors.green,
                                  duration: Duration(seconds: 2),
                                ),
                              );
                              Navigator.pop(context, address);
                            }
                          } else {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text(
                                        'Lỗi: ${authViewModel.errorMessage}')),
                              );
                            }
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text('Lỗi khi lưu địa chỉ: $e')),
                            );
                          }
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                backgroundColor: Colors.blueAccent,
              ),
              child: isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      "XÁC NHẬN",
                      style: TextStyle(color: Colors.white),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label) {
    return TextFormField(
      controller: _streetController,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      validator: (value) => (value == null || value.trim().isEmpty)
          ? 'Vui lòng nhập $label'
          : null,
    );
  }

  Widget _buildCitySelector() {
    return GestureDetector(
      onTap: isLoading || provinces.isEmpty
          ? null
          : () async {
              final selected = await showModalBottomSheet<Map<String, dynamic>>(
                backgroundColor: Colors.white,
                isScrollControlled: true,
                context: context,
                builder: (context) {
                  final screenHeight = MediaQuery.of(context).size.height;
                  return Container(
                    height: screenHeight * 0.85,
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        const Text(
                          'Chọn Tỉnh/Thành phố',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: isLoading
                              ? const Center(child: CircularProgressIndicator())
                              : ListView.builder(
                                  itemCount: provinces.length,
                                  itemBuilder: (context, index) {
                                    final province = provinces[index];
                                    return ListTile(
                                      title: Text(province['name'] ?? ''),
                                      onTap: () {
                                        Navigator.pop(context, province);
                                      },
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  );
                },
              );

              if (selected != null && mounted) {
                setState(() {
                  selectedProvince = selected['name'];
                  selectedProvinceCode = selected['code'].toString();
                  districts.clear();
                  wards.clear();
                  selectedDistrict = null;
                  selectedWard = null;
                });
                await _fetchDistricts(selectedProvinceCode!);
              }
            },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade400),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(selectedProvince ?? 'Tỉnh/Thành phố *'),
            if (!isLoading) const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }

  Widget _buildDistrictSelector() {
    return GestureDetector(
      onTap: isLoading || districts.isEmpty
          ? null
          : () async {
              final selectedDistrictItem =
                  await showModalBottomSheet<Map<String, dynamic>>(
                backgroundColor: Colors.white,
                isScrollControlled: true,
                context: context,
                builder: (context) {
                  final screenHeight = MediaQuery.of(context).size.height;
                  return Container(
                    height: screenHeight * 0.7,
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        const Text(
                          'Chọn Quận/Huyện',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: isLoading
                              ? const Center(child: CircularProgressIndicator())
                              : ListView.builder(
                                  itemCount: districts.length,
                                  itemBuilder: (context, index) {
                                    final district = districts[index];
                                    return ListTile(
                                      title: Text(district['name'] ?? ''),
                                      onTap: () {
                                        Navigator.pop(context, district);
                                      },
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  );
                },
              );

              if (selectedDistrictItem != null && mounted) {
                setState(() {
                  selectedDistrict =
                      selectedDistrictItem['name']; // Sửa: Gán đúng vào state
                  selectedWard = null;
                  wards.clear();
                });
                await _fetchWards(selectedDistrictItem['code'].toString());
              }
            },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade400),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(selectedDistrict ?? 'Chọn Quận/Huyện *'),
            if (!isLoading) const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }

  Widget _buildWardSelector() {
    return GestureDetector(
      onTap: isLoading || wards.isEmpty
          ? null
          : () async {
              final selectedWardItem =
                  await showModalBottomSheet<Map<String, dynamic>>(
                backgroundColor: Colors.white,
                isScrollControlled: true,
                context: context,
                builder: (ctx) {
                  final screenHeight = MediaQuery.of(ctx).size.height;
                  return Container(
                    height: screenHeight * 0.7,
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        const Text(
                          'Chọn Xã/Phường',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: isLoading
                              ? const Center(child: CircularProgressIndicator())
                              : ListView.builder(
                                  itemCount: wards.length,
                                  itemBuilder: (context, index) {
                                    final ward = wards[index];
                                    return ListTile(
                                      title: Text(ward['name'] ?? ''),
                                      onTap: () {
                                        Navigator.pop(context, ward);
                                      },
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  );
                },
              );

              if (selectedWardItem != null && mounted) {
                setState(() {
                  selectedWard = selectedWardItem['name'];
                });
              }
            },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade400),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(selectedWard ?? 'Chọn Xã/Phường *'),
            if (!isLoading) const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultSwitch() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text("Đặt làm địa chỉ mặc định"),
        Switch(
          value: isDefault,
          onChanged:
              isLoading ? null : (value) => setState(() => isDefault = value),
          activeColor: Colors.blueAccent,
        ),
      ],
    );
  }
}
