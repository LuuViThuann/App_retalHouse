import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/rental.dart';
import '../viewmodels/vm_booking.dart';
import '../constants/app_color.dart';

class TestBookingView extends StatelessWidget {
  const TestBookingView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Booking'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Test BookingViewModel',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Consumer<BookingViewModel>(
              builder: (context, bookingViewModel, child) {
                return Column(
                  children: [
                    Text('Is Loading: ${bookingViewModel.isLoading}'),
                    Text('Is Creating: ${bookingViewModel.isCreating}'),
                    Text('Error: ${bookingViewModel.errorMessage ?? 'None'}'),
                    Text(
                        'My Bookings Count: ${bookingViewModel.myBookings.length}'),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {
                        bookingViewModel.clearError();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Error cleared')),
                        );
                      },
                      child: const Text('Clear Error'),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
