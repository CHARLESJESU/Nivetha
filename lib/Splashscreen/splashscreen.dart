import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:nivetha123/Pages/jobproviderpage.dart';
import 'package:nivetha123/Pages/workerpage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../login/Login.dart';
import '../screens/user_data.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  // Method to check login status and navigate to the appropriate page
  Future<void> _checkLoginStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    bool isWorker = prefs.getBool('isworker') ?? false;
    String? userDataJson = prefs.getString('userData');

    // If user data exists, decode and create the UserData object
    UserData? userData;
    if (userDataJson != null) {
      Map<String, dynamic> jsonMap = jsonDecode(userDataJson);
      userData = UserData.fromJson(jsonMap);
    }

    // Navigate based on login status and user role
    if (isLoggedIn && userData != null) {
      if (isWorker) {
        // Navigate to WorkerPage
        Get.off(() => Workerpage(userData: userData!));
      } else {
        // Navigate to JobProviderPage
        Get.off(() => Jobproviderpage(userData: userData!));
      }
    } else {
      // Navigate to LoginScreen if not logged in
      Get.off(() => LoginScreen());
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
            SizedBox(
              width: 250,
              height: 250,
              child: Image.asset("assets/images/splash.png"), // Splash image
            ),
          ],
        ),
      ),
    );
  }
}
