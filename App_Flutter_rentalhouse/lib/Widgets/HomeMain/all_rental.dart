import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/viewmodels/vm_rental.dart';
import 'package:provider/provider.dart';
import '../../views/main_list_cart_home.dart';

class AllLatestPostsScreen extends StatefulWidget {
  const AllLatestPostsScreen({super.key});

  @override
  _AllLatestPostsScreenState createState() => _AllLatestPostsScreenState();
}

class _AllLatestPostsScreenState extends State<AllLatestPostsScreen> {
  int _displayLimit = 5; // Initial limit of posts to display

  @override
  Widget build(BuildContext context) {
    final rentalViewModel = Provider.of<RentalViewModel>(context);
    final today = DateTime.now();
    final latestRentals = rentalViewModel.rentals
        .where((rental) => rental.createdAt.year == today.year)
        .toList();

    // Calculate the number of posts to display
    final displayRentals = latestRentals.take(_displayLimit).toList();
    final hasMorePosts = _displayLimit < latestRentals.length;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text(
          'Bài đăng mới nhất',
          style: TextStyle(color: Colors.black),
        ),
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
              : latestRentals.isEmpty
                  ? const Center(
                      child: Text(
                        'Không có bài đăng mới trong tháng này!',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16.0),
                      itemCount: displayRentals.length + (hasMorePosts ? 1 : 0),
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 12),
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
                                    style: TextStyle(
                                        fontSize: 14, color: Colors.blue[700]),
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
