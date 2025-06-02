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
  String addressType = 'Văn Phòng';

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
    final response = await http.get(ApiRoutes.provinces);
    if (response.statusCode == 200) {
      setState(() {
        provinces = json.decode(utf8.decode(response.bodyBytes));
        isLoading = false;
      });
    } else {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể tải dữ liệu tỉnh')),
      );
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
          districts = List<Map<String, dynamic>>.from(data['districts']);
          isLoading = false;
        });
      } else {
        throw Exception('Failed to load districts');
      }
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi tải huyện: $e')),
      );
    }
  }

  Future<void> _fetchWards(String districtCode) async {
    setState(() => isLoading = true);
    final response = await http.get(ApiRoutes.getWards(districtCode));
    if (response.statusCode == 200) {
      setState(() {
        wards = json.decode(utf8.decode(response.bodyBytes))['wards'];
        isLoading = false;
      });
    } else {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể tải dữ liệu xã')),
      );
    }
  }

  String _formatAddress() {
    final parts = [
      _streetController.text,
      selectedWard,
      selectedDistrict,
      selectedProvince,
      if (addressType.isNotEmpty) '($addressType)',
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
            _buildTextField('Tên đường, Tòa nhà, Số nhà'),
            const SizedBox(height: 24),
            _buildDefaultSwitch(),
            const SizedBox(height: 12),
            _buildAddressType(),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () async {
                if (_formKey.currentState!.validate()) {
                  if (selectedProvince == null ||
                      selectedDistrict == null ||
                      _streetController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content:
                              Text('Vui lòng điền đầy đủ thông tin địa chỉ')),
                    );
                    return;
                  }

                  final address = _formatAddress();
                  final authViewModel =
                      Provider.of<AuthViewModel>(context, listen: false);

                  try {
                    await authViewModel.updateUserProfile(
                      phoneNumber: authViewModel.currentUser?.phoneNumber ?? '',
                      address: address,
                      username: authViewModel.currentUser?.username ?? '',
                    );

                    if (authViewModel.errorMessage == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Địa chỉ đã được lưu thành công!'),
                          backgroundColor: Colors.green,
                          duration: Duration(seconds: 2),
                        ),
                      );
                      Navigator.pop(context, address);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content:
                                Text('Lỗi: ${authViewModel.errorMessage}')),
                      );
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Lỗi khi lưu địa chỉ: $e')),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                backgroundColor: Colors.blueAccent,
              ),
              child: const Text(
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
      validator: (value) =>
          (value == null || value.isEmpty) ? 'Vui lòng nhập $label' : null,
    );
  }

  Widget _buildCitySelector() {
    return GestureDetector(
      onTap: () async {
        if (provinces.isEmpty) return;

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
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
                                title: Text(province['name']),
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
            Text(selectedProvince ?? 'Tỉnh/Thành phố'),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }

  Widget _buildDistrictSelector() {
    return GestureDetector(
      onTap: () async {
        if (districts.isEmpty) return;

        final selectedDistrict =
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
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
                                title: Text(district['name']),
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

        if (selectedDistrict != null && mounted) {
          setState(() {
            this.selectedDistrict = selectedDistrict['name'];
            selectedWard = null;
            wards.clear();
          });
          await _fetchWards(selectedDistrict['code'].toString());
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
            Text(selectedDistrict ?? 'Chọn Quận/Huyện'),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }

  Widget _buildWardSelector() {
    return GestureDetector(
      onTap: () async {
        if (wards.isEmpty) return;

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
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
                                title: Text(ward['name']),
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
            Text(selectedWard ?? 'Chọn Xã/Phường'),
            const Icon(Icons.chevron_right),
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
          onChanged: (value) => setState(() => isDefault = value),
          activeColor: Colors.white,
          activeTrackColor: Colors.blueAccent,
          inactiveThumbColor: Colors.grey[400],
          inactiveTrackColor: Colors.grey[300],
        ),
      ],
    );
  }

  Widget _buildAddressType() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _addressTypeChip("Văn Phòng"),
        _addressTypeChip("Nhà Riêng"),
      ],
    );
  }

  Widget _addressTypeChip(String type) {
    final isSelected = addressType == type;
    return ChoiceChip(
      label: Text(type),
      selected: isSelected,
      onSelected: (_) => setState(() => addressType = type),
      selectedColor: Colors.blueAccent,
      labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black),
    );
  }
}
