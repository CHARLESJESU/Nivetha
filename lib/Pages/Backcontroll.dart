import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class BackButtonController extends GetxController {
  DateTime? _lastPressed;

  Future<bool> handleWillPop() async {
    DateTime now = DateTime.now();
    if (_lastPressed == null ||
        now.difference(_lastPressed!) > Duration(seconds: 2)) {
      _lastPressed = now;

      // ✅ Styled snackbar (only this changed)
      Get.closeAllSnackbars(); // Close previous snackbars if any
      Get.snackbar(
        'Exit App',
        'Press back again to exit',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.black87,
        colorText: Colors.white,
        margin: EdgeInsets.all(12),
        borderRadius: 10,
        duration: Duration(seconds: 2),
        icon: Icon(Icons.exit_to_app, color: Colors.white),
      );

      return false;
    }
    return true;
  }
}

class FullImagePage extends StatelessWidget {
  final String imageBase64;

  const FullImagePage({Key? key, required this.imageBase64}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Full Image')),
      body: Center(child: Image.memory(base64Decode(imageBase64))),
    );
  }
}
