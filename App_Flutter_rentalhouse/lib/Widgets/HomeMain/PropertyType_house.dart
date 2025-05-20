import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/viewmodels/vm_rental.dart';
import 'package:flutter_rentalhouse/views/main_list_cart_home.dart';
import 'package:provider/provider.dart';

class PropertyTypeScreen extends StatefulWidget {
  final String propertyType;

  const PropertyTypeScreen({super.key, required this.propertyType});

  @override
  _PropertyTypeScreenState createState() => _PropertyTypeScreenState();
}

class _PropertyTypeScreenState extends State<PropertyTypeScreen> {
  int _displayLimit = 5; // Initial limit of posts to display

  @override
  Widget build(BuildContext context) {
    final rentalViewModel = Provider.of<RentalViewModel>(context);

    final filteredRentals = rentalViewModel.rentals
        .where((rental) => rental.propertyType == widget.propertyType)
        .toList();

    // Calculate the number of posts to display
    final displayRentals = filteredRentals.take(_displayLimit).toList();
    final hasMorePosts = _displayLimit < filteredRentals.length;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          widget.propertyType,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue, Colors.blueAccent.shade700],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        elevation: 4,
        shadowColor: Colors.black26,
      ),

      body: rentalViewModel.isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.blue))
          : rentalViewModel.errorMessage != null
          ? Center(
        child: Text(
          'Lỗi: ${rentalViewModel.errorMessage}',
          style: const TextStyle(color: Colors.red, fontSize: 16),
        ),
      )
          : filteredRentals.isEmpty
          ? const Center(
        child: Text(
          'Không có bài đăng nào!',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      )
          : ListView.separated(
        padding: const EdgeInsets.all(16.0),
        itemCount: displayRentals.length + (hasMorePosts ? 1 : 0),
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (hasMorePosts && index == displayRentals.length) {
            // Display "Xem thêm bài đăng" button
            return Center(
              child: TextButton(
                onPressed: () {
                  setState(() {
                    _displayLimit += 5; // Load 5 more posts
                  });
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Xem thêm bài đăng',
                      style: TextStyle(fontSize: 14, color: Colors.blue[700]),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward,
                      size: 14,
                      color: Colors.blue[700],
                    ),
                  ],
                ),
              ),
            );
          }
          return RentalItemWidget(rental: displayRentals[index]);
        },
      ),
    );
  }
}


