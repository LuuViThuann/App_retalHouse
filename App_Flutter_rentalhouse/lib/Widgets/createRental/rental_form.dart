import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/viewmodels/vm_auth.dart';

import '../../models/rental.dart';

class FormStateManager {
  final AuthViewModel authViewModel;

  TextEditingController? titleController;
  TextEditingController? priceController;
  TextEditingController? areaTotalController;
  TextEditingController? areaLivingRoomController;
  TextEditingController? areaBedroomsController;
  TextEditingController? areaBathroomsController;
  TextEditingController? locationShortController;
  TextEditingController? locationFullAddressController;
  TextEditingController? furnitureController;
  TextEditingController? amenitiesController;
  TextEditingController? surroundingsController;
  TextEditingController? rentalTermsMinimumLeaseController;
  TextEditingController? rentalTermsDepositController;
  TextEditingController? rentalTermsPaymentMethodController;
  TextEditingController? rentalTermsRenewalTermsController;
  TextEditingController? contactInfoNameController;
  TextEditingController? contactInfoPhoneController;
  TextEditingController? contactInfoAvailableHoursController;

  bool _isInitialized = false;

  FormStateManager({required this.authViewModel}) {
    initializeControllers();
  }

  void initializeControllers() {
    if (_isInitialized) return; // Prevent reinitialization

    titleController = TextEditingController();
    priceController = TextEditingController();
    areaTotalController = TextEditingController();
    areaLivingRoomController = TextEditingController();
    areaBedroomsController = TextEditingController();
    areaBathroomsController = TextEditingController();
    locationShortController = TextEditingController();
    locationFullAddressController = TextEditingController();
    furnitureController = TextEditingController();
    amenitiesController = TextEditingController();
    surroundingsController = TextEditingController();
    rentalTermsMinimumLeaseController = TextEditingController();
    rentalTermsDepositController = TextEditingController();
    rentalTermsPaymentMethodController = TextEditingController();
    rentalTermsRenewalTermsController = TextEditingController();
    contactInfoNameController = TextEditingController(
      text: authViewModel.currentUser?.username ?? '',
    );
    contactInfoPhoneController = TextEditingController(
      text: authViewModel.currentUser?.phoneNumber ?? '',
    );
    contactInfoAvailableHoursController = TextEditingController();

    _isInitialized = true;
  }

  Rental buildRental({
    required List<String> images,
    required String propertyType,
    required String status,
    required String userId,
  }) {
    final rawPrice = priceController!.text.replaceAll(RegExp(r'[^\d]'), '');
    final rawDeposit =
        rentalTermsDepositController!.text.replaceAll(RegExp(r'[^\d]'), '');

    return Rental(
      id: '',
      title: titleController!.text.trim(),
      price: double.tryParse(rawPrice) ?? 0.0,
      area: {
        'total': double.tryParse(areaTotalController!.text.trim()) ?? 0.0,
        'livingRoom': areaLivingRoomController!.text.trim().isEmpty
            ? 0.0
            : double.tryParse(areaLivingRoomController!.text.trim()) ?? 0.0,
        'bedrooms': areaBedroomsController!.text.trim().isEmpty
            ? 0.0
            : double.tryParse(areaBedroomsController!.text.trim()) ?? 0.0,
        'bathrooms': areaBathroomsController!.text.trim().isEmpty
            ? 0.0
            : double.tryParse(areaBathroomsController!.text.trim()) ?? 0.0,
      },
      location: {
        'short': locationShortController!.text.trim(),
        'fullAddress': locationFullAddressController!.text.trim(),
      },
      propertyType: propertyType,
      furniture: furnitureController!.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(),
      amenities: amenitiesController!.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(),
      surroundings: surroundingsController!.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(),
      rentalTerms: {
        'minimumLease': rentalTermsMinimumLeaseController!.text.trim(),
        'deposit': rawDeposit,
        'paymentMethod': rentalTermsPaymentMethodController!.text.trim(),
        'renewalTerms': rentalTermsRenewalTermsController!.text.trim(),
      },
      contactInfo: {
        'name': contactInfoNameController!.text.trim(),
        'phone': contactInfoPhoneController!.text.trim(),
        'availableHours': contactInfoAvailableHoursController!.text.trim(),
      },
      userId: userId,
      images: images,
      status: status,
      createdAt: DateTime.now(),
      landlord: userId,
    );
  }

  void dispose() {
    titleController?.dispose();
    priceController?.dispose();
    areaTotalController?.dispose();
    areaLivingRoomController?.dispose();
    areaBedroomsController?.dispose();
    areaBathroomsController?.dispose();
    locationShortController?.dispose();
    locationFullAddressController?.dispose();
    furnitureController?.dispose();
    amenitiesController?.dispose();
    surroundingsController?.dispose();
    rentalTermsMinimumLeaseController?.dispose();
    rentalTermsDepositController?.dispose();
    rentalTermsPaymentMethodController?.dispose();
    rentalTermsRenewalTermsController?.dispose();
    contactInfoNameController?.dispose();
    contactInfoPhoneController?.dispose();
    contactInfoAvailableHoursController?.dispose();
  }
}
