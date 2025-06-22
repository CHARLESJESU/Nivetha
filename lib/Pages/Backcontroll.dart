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

      // ✅ Normal ScaffoldMessenger snackbar
      final context = Get.context;
      if (context != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Press back again to exit'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.all(12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }

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
