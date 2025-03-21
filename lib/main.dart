import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:nivetha123/Splashscreen/splashscreen.dart';

import 'login/Login.dart';



Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isAndroid) {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: 'AIzaSyBEwHmL7vCRvFhT0E4PgRuljZz8WeEc64Q',
        appId: '1:582445629498:android:816d99eecc14d96f2e3503',
        messagingSenderId: '582445629498',
        projectId: 'phoneauthfire-34a07',
      ),
    );
  } else {
    await Firebase.initializeApp();
  }


  runApp(const Myapp());
}
class Myapp extends StatefulWidget {
  const Myapp({super.key});

  @override
  State<Myapp> createState() => _MyappState();
}

class _MyappState extends State<Myapp> {
  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      home: SplashScreen(),
    );
  }
}
