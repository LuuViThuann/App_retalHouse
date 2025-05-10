import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/viewmodels/vm_auth.dart';
import 'package:flutter_rentalhouse/viewmodels/vm_rental.dart';
import 'package:flutter_rentalhouse/views/change_password_view.dart';
import 'package:flutter_rentalhouse/views/create_rental_view.dart';
import 'package:flutter_rentalhouse/views/login_view.dart';
import 'package:provider/provider.dart';


class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final rentalViewModel = Provider.of<RentalViewModel>(context);
    final authViewModel = Provider.of<AuthViewModel>(context);

    if (!rentalViewModel.isLoading && rentalViewModel.rentals.isEmpty) {
      rentalViewModel.fetchRentals();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Nhà Cho Thuê'),
        actions: [
          IconButton(
            icon: Icon(Icons.lock),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ChangePasswordScreen()),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () async {
              await authViewModel.logout();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => LoginScreen()),
              );
            },
          ),
        ],
      ),
      body: rentalViewModel.isLoading
          ? Center(child: CircularProgressIndicator())
          : rentalViewModel.errorMessage != null
          ? Center(child: Text(rentalViewModel.errorMessage!))
          : ListView.builder(
        itemCount: rentalViewModel.rentals.length,
        itemBuilder: (context, index) {
          final rental = rentalViewModel.rentals[index];
          return Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (rental.images.isNotEmpty)
                  SizedBox(
                    height: 150,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: rental.images.length,
                      itemBuilder: (context, imgIndex) {
                        return Padding(
                          padding: EdgeInsets.all(4.0),
                          child: Image.network(
                            'http://localhost:3000${rental.images[imgIndex]}',
                            width: 150,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Icon(Icons.error),
                          ),
                        );
                      },
                    ),
                  ),
                ListTile(
                  title: Text(rental.title),
                  subtitle: Text('${rental.location} - ${rental.price} VND'),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => CreateRentalScreen()),
          ).then((_) => rentalViewModel.fetchRentals());
        },
        child: Icon(Icons.add),
      ),
    );
  }
}