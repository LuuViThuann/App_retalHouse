import 'package:flutter/material.dart';

class ContractView extends StatefulWidget {
  const ContractView({super.key});

  @override
  State<ContractView> createState() => _ContractViewState();
}

class _ContractViewState extends State<ContractView> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Text("Trang hợp đồng"),
      ),
    );
  }
}
