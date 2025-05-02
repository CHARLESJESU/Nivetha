import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class Post {
  final String userId;
  final String postId;
  final String description;
  final String imageBase64;

  Post({
    required this.userId,
    required this.postId,
    required this.description,
    required this.imageBase64,
  });
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
