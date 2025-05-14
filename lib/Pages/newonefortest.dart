import 'package:flutter/material.dart';

class Hida extends StatefulWidget {
  final String userexist; // ✅ Store it as a field

  const Hida({super.key, required this.userexist}); // ✅ Assign via constructor

  @override
  State<Hida> createState() => _HidaState();
}

class _HidaState extends State<Hida> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.userexist), // ✅ Access with widget.userexist
        backgroundColor: Colors.blue,
      ),
    );
  }
}
