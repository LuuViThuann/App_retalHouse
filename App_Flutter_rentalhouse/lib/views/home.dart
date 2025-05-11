import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/viewmodels/vm_rental.dart';
import 'package:flutter_rentalhouse/views/create_rental_view.dart';
import 'package:provider/provider.dart';
import '../viewmodels/vm_auth.dart';
import '../views/login_view.dart';
import '../config/api_routes.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Lấy danh sách bài đăng khi màn hình khởi tạo
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final rentalViewModel = Provider.of<RentalViewModel>(context, listen: false);
      rentalViewModel.fetchRentals();
    });
  }

  @override
  Widget build(BuildContext context) {

    final rentalViewModel = Provider.of<RentalViewModel>(context);
    final authViewModel = Provider.of<AuthViewModel>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Danh Sách Bài Đăng'),
        actions: [
          if (authViewModel.currentUser != null)
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () async {
                await authViewModel.logout();
                if (authViewModel.errorMessage == null) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(authViewModel.errorMessage!),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
            ),
        ],
      ),
      body: rentalViewModel.isLoading
          ? const Center(child: CircularProgressIndicator())
          : rentalViewModel.errorMessage != null
          ? Center(child: Text('Lỗi: ${rentalViewModel.errorMessage}'))
          : rentalViewModel.rentals.isEmpty
          ? const Center(child: Text('Không có bài đăng nào!'))
          : ListView.builder(
        itemCount: rentalViewModel.rentals.length,
        itemBuilder: (context, index) {
          final rental = rentalViewModel.rentals[index];
          return ListTile(
            title: Text(rental.title),
            subtitle: Text('${rental.location} - ${rental.price} VND'),
            leading: rental.images.isNotEmpty
                ? CachedNetworkImage(
              imageUrl: '${ApiRoutes.baseUrl.replaceAll('/api', '')}${rental.images[0]}',
              width: 50,
              height: 50,
              fit: BoxFit.cover,
              placeholder: (context, url) => const CircularProgressIndicator(),
              errorWidget: (context, url, error) => const Icon(Icons.error),
            )
                : const Icon(Icons.image),
            onTap: () {
              // Xử lý khi nhấn vào bài đăng (ví dụ: xem chi tiết)
            },
          );
        },
      ),
      floatingActionButton: authViewModel.currentUser != null
          ? FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreateRentalScreen()),
          );
        },
        child: const Icon(Icons.add),
      )
          : null,
    );
  }
}