import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:nivetha123/Pages/workacceptor.dart';
import 'package:nivetha123/Pages/workprovider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../login/Login.dart';
import '../screens/name_job.dart';
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

  Future<void> _checkLoginStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    bool isworker = prefs.getBool('isworker') ?? false;

    Future.delayed(const Duration(seconds: 1), () {
      isLoggedIn
          ? (isworker
              ? Get.off(Workacceptor())
              : //Get.off(Workprovider())
              Get.off(Page1NameRole(userData: UserData())))
          : Get.off(LoginScreen());
    });
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
              child: Image.asset("assets/images/splash.png"),
            ),
          ],
        ),
      ),
    );
  }
}
