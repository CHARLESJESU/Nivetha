import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../login/Login.dart';

class Workacceptor extends StatefulWidget {
  const Workacceptor({super.key});

  @override
  State<Workacceptor> createState() => _WorkacceptorStatState();
}

class _WorkacceptorStatState extends State<Workacceptor> {
  void initState() {
    super.initState();
    _initializePreferences();
  }

  void _initializePreferences() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          Padding(
            padding: EdgeInsets.only(right: 20),
            child: IconButton(
              onPressed: () async {
                bool shouldLogout = await Get.defaultDialog(
                  title: "Confirm Logout",
                  middleText: "Are you sure you want to logout?",
                  actions: [
                    ElevatedButton(
                      onPressed: () {
                        Get.off(LoginScreen());
                      },
                      child: Text(
                        "Confirm",
                        style: TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Get.back();
                      },
                      child: Text(
                        "Cancel",
                        style: TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                    ),
                  ],
                );

                if (shouldLogout == true) {
                  SharedPreferences prefs =
                      await SharedPreferences.getInstance();
                  await prefs.setBool('isLoggedIn', false);
                  await prefs.setBool('isworker', true);

                  Get.offAll(
                    () => const LoginScreen(),
                  ); // Clears previous routes and navigates to login
                }
              },
              icon: Icon(Icons.logout, color: Colors.white),
            ),
          ),
        ],
        automaticallyImplyLeading: false,
        title: Text(
          "Work Acceptor Page",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blue,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 200,
              height: 200,
              child: Image.asset('assets/images/splash.png'),
            ),
          ],
        ),
      ),
    );
  }
}
