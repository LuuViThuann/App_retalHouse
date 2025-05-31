import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_rentalhouse/Widgets/createRental/area.dart';
import 'package:flutter_rentalhouse/Widgets/createRental/contact_info.dart';
import 'package:flutter_rentalhouse/Widgets/createRental/detail_create_rental.dart';
import 'package:flutter_rentalhouse/Widgets/createRental/image_choice.dart';
import 'package:flutter_rentalhouse/Widgets/createRental/info_basic_rental.dart';
import 'package:flutter_rentalhouse/Widgets/createRental/location.dart';
import 'package:flutter_rentalhouse/Widgets/createRental/rental_form.dart';
import 'package:flutter_rentalhouse/Widgets/createRental/term_rental.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:lottie/lottie.dart';
import 'dart:io';
import '../config/loading.dart';
import '../models/rental.dart';
import '../viewmodels/vm_auth.dart';
import '../viewmodels/vm_rental.dart';
import '../Widgets/Detail/full_screen_image.dart';
import '../Widgets/thousand_format.dart';

class CreateRentalScreen extends StatefulWidget {
  const CreateRentalScreen({super.key});

  @override
  _CreateRentalScreenState createState() => _CreateRentalScreenState();
}

class _CreateRentalScreenState extends State<CreateRentalScreen> {
  final _formKey = GlobalKey<FormState>();
  late final FormStateManager _formStateManager;
  final ValueNotifier<List<File>> _imagesNotifier =
      ValueNotifier<List<File>>([]);
  final ValueNotifier<String?> _propertyTypeNotifier =
      ValueNotifier<String?>(null);
  final ValueNotifier<String> _statusNotifier =
      ValueNotifier<String>('Đang hoạt động');

  @override
  void initState() {
    super.initState();
    _formStateManager = FormStateManager(
      authViewModel: Provider.of<AuthViewModel>(context, listen: false),
    );
    _formStateManager.initializeControllers();
  }

  @override
  void dispose() {
    _formStateManager.dispose();
    _imagesNotifier.dispose();
    _propertyTypeNotifier.dispose();
    _statusNotifier.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
      final rentalViewModel =
          Provider.of<RentalViewModel>(context, listen: false);

      if (authViewModel.currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vui lòng đăng nhập để tạo bài đăng.'),
            backgroundColor: Colors.redAccent,
          ),
        );
        try {
          await Navigator.pushNamed(context, '/login');
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lỗi điều hướng đến trang đăng nhập: $e'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        return;
      }

      if (_imagesNotifier.value.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vui lòng chọn ít nhất một ảnh minh họa.'),
            backgroundColor: Colors.orangeAccent,
          ),
        );
        return;
      }

      if (_imagesNotifier.value.length > 10) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tối đa 10 ảnh được phép tải lên.'),
            backgroundColor: Colors.orangeAccent,
          ),
        );
        return;
      }

      final rental = _formStateManager.buildRental(
        images: _imagesNotifier.value.map((file) => file.path).toList(),
        propertyType: _propertyTypeNotifier.value ?? 'Khác',
        status:
            _statusNotifier.value == 'Đang hoạt động' ? 'available' : 'rented',
        userId: authViewModel.currentUser!.id,
      );

      try {
        await rentalViewModel.createRental(
          rental,
          _imagesNotifier.value.map((file) => file.path).toList(),
        );

        if (mounted) {
          if (rentalViewModel.errorMessage == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Tạo bài đăng thành công!'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 3),
              ),
            );
            Navigator.pop(context, true);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Lỗi: ${rentalViewModel.errorMessage!}'),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lỗi khi tạo bài đăng: $e'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Thông tin chưa hợp lệ. Vui lòng kiểm tra lại các trường được đánh dấu *',
          ),
          backgroundColor: Colors.orangeAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final rentalViewModel = Provider.of<RentalViewModel>(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Tạo Bài Đăng Mới'),
        elevation: 1.5,
        backgroundColor: Colors.white,
        foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              BasicInfoForm(
                titleController: _formStateManager.titleController!,
                priceController: _formStateManager.priceController!,
                statusNotifier: _statusNotifier,
              ),
              AreaForm(
                totalController: _formStateManager.areaTotalController!,
                livingRoomController:
                    _formStateManager.areaLivingRoomController!,
                bedroomsController: _formStateManager.areaBedroomsController!,
                bathroomsController: _formStateManager.areaBathroomsController!,
              ),
              LocationForm(
                shortController: _formStateManager.locationShortController!,
                fullAddressController:
                    _formStateManager.locationFullAddressController!,
              ),
              PropertyDetailsForm(
                propertyTypeNotifier: _propertyTypeNotifier,
                furnitureController: _formStateManager.furnitureController!,
                amenitiesController: _formStateManager.amenitiesController!,
                surroundingsController:
                    _formStateManager.surroundingsController!,
              ),
              RentalTermsForm(
                minimumLeaseController:
                    _formStateManager.rentalTermsMinimumLeaseController!,
                depositController:
                    _formStateManager.rentalTermsDepositController!,
                paymentMethodController:
                    _formStateManager.rentalTermsPaymentMethodController!,
                renewalTermsController:
                    _formStateManager.rentalTermsRenewalTermsController!,
              ),
              ContactInfoForm(
                nameController: _formStateManager.contactInfoNameController!,
                phoneController: _formStateManager.contactInfoPhoneController!,
                availableHoursController:
                    _formStateManager.contactInfoAvailableHoursController!,
              ),
              ImagePickerForm(
                imagesNotifier: _imagesNotifier,
                onImageTap: (file) => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        FullScreenImageScreen(imageUrl: file.path),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              if (rentalViewModel.isLoading)
                Center(
                  child: Lottie.asset(
                    AssetsConfig.loadingLottie,
                    width: 100,
                    height: 100,
                    fit: BoxFit.fill,
                  ),
                )
              else
                ElevatedButton.icon(
                  icon: const Icon(Icons.cloud_upload_outlined),
                  label: const Text('Đăng Bài'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 52),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    textStyle: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.bold),
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _submitForm,
                ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
