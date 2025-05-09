import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:nivetha123/Splashscreen/splashscreen.dart';

import 'login/Login.dart';

String globalEmail = '';
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isAndroid) {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: 'AIzaSyD2NdzsbCi-XnhYHV0WAyCUkJyxmabyE7M',
        appId: '1:228919231041:android:2446454b88391cc640bcc0',
        messagingSenderId: '228919231041',
        projectId: 'dinnertonight-3d9ce',
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
