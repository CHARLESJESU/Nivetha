import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nivetha123/Pages/jobproviderpage.dart';
import 'package:nivetha123/Pages/workerpage.dart';
import 'package:nivetha123/screens/user_data.dart';

class CheckboxAnimationPage extends StatefulWidget {
  final bool success;
  final UserData? userData;

  const CheckboxAnimationPage({Key? key, required this.success, this.userData})
    : super(key: key);

  @override
  _CheckboxAnimationPageState createState() => _CheckboxAnimationPageState();
}

class _CheckboxAnimationPageState extends State<CheckboxAnimationPage> {
  bool isChecked = false;

  @override
  void initState() {
    super.initState();

    // Run the animation and navigate only if registration was successful
    if (widget.success) {
      _runAnimationAndNavigate();
    }
  }

  // A helper method to handle animation and navigation logic
  Future<void> _runAnimationAndNavigate() async {
    // Trigger the checkbox animation
    setState(() {
      isChecked = true;
    });

    // Wait for the animation to complete before navigating
    await Future.delayed(const Duration(seconds: 1));

    if (widget.userData != null) {
      final prefs = await SharedPreferences.getInstance();
      // Store user data as a JSON string in shared preferences
      await prefs.setString('userData', jsonEncode(widget.userData!.toJson()));

      // Navigate based on user role (Worker or Job Provider)
      Widget nextPage =
          widget.userData!.role == 'Worker'
              ? Workerpage(userData: widget.userData!)
              : Jobproviderpage(userData: widget.userData!);

      // Replace the current screen with the appropriate page
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => nextPage),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated container for checkbox effect
            AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              width: isChecked ? 150 : 70,
              height: isChecked ? 150 : 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isChecked ? Colors.blue : Colors.grey[300],
              ),
              child:
                  isChecked
                      ? const Icon(Icons.check, size: 100, color: Colors.white)
                      : const SizedBox.shrink(),
            ),
            const SizedBox(height: 30),
            // Display appropriate success message
            Text(
              widget.success
                  ? "Registration Successful!"
                  : "Please accept the Terms & Conditions.",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            // If registration wasn't successful, show a "Go Back" button
            if (!widget.success)
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Go Back"),
              ),
          ],
        ),
      ),
    );
  }
}
