import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as path;
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';


class FormPage extends StatefulWidget {
  final String userId;

  FormPage({required this.userId});

  @override
  _FormPageState createState() => _FormPageState();
}

class _FormPageState extends State<FormPage> {
  File? _imageFile;
  final TextEditingController _descriptionController = TextEditingController();
  final CollectionReference _jobCollection = FirebaseFirestore.instance
      .collection('jobs')
      .doc('workers')
      .collection('workers');

  bool _isUploading = false;

  bool _showSuccessAnimation = false;
  String _generatedOrderId = '';

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _imageFile = File(picked.path);
      });
    }
  }


  Future<String?> compressAndConvertToBase64(String imagePath) async {
    try {
      // Get temporary directory
      final tempDir = await getTemporaryDirectory();
      final targetPath = path.join(
        tempDir.path,
        'compressed_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      // Compress image
      final compressedFile = await FlutterImageCompress.compressAndGetFile(
        imagePath,
        targetPath,
        quality: 40,
        format: CompressFormat.jpeg,
      );

      // Validate compression result
      if (compressedFile == null || !await File(compressedFile.path).exists()) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Image compression failed.")),
        );
        return null;
      }

      // Read compressed image as bytes and encode to base64
      final bytes = await compressedFile.readAsBytes();
      print("Compressed size: ${bytes.length} bytes");
      return base64Encode(bytes);
    } catch (e) {
      print("Compression or conversion failed: $e");
      return null;
    }
  }


  String _generateOrderId() {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rand = Random.secure();
    final id =
    List.generate(7, (index) => chars[rand.nextInt(chars.length)]).join();
    return id; // just the random string, no prefix here
  }

  Future<void> _uploadOrder() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("User not logged in")),
      );
      return;
    }

    if (_imageFile == null || _descriptionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please select an image and enter a description")),
      );
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      final userId = widget.userId;
      print(_imageFile);

      final base64Image = await compressAndConvertToBase64(_imageFile!.path);
      print(base64Image);

      final rawOrderId = _generateOrderId();
      final orderKey = 'OID_$rawOrderId';

      final userDocRef = FirebaseFirestore.instance
          .collection('jobs')
          .doc('workers')
          .collection('workers')
          .doc(userId);

// ✅ First, set a field in the user doc
      await userDocRef.set(
          {'summa': 1}, SetOptions(merge: true)); // merge to avoid overwrite

// ✅ Then, add order to the subcollection
      await userDocRef
          .collection('order')
          .doc(orderKey)
          .set({
        'orderkey': orderKey,
        'description': _descriptionController.text,
        'imageBase64': base64Image,
      });

      setState(() {
        _showSuccessAnimation = true;
        _generatedOrderId = orderKey;
      });

      Future.delayed(Duration(seconds: 3), () {
        if (mounted) Navigator.of(context).pop();
      });
    }catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to post job: $e")),
      );
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }


  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Post Job")),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Enter Description",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Container(
                    height: 100,
                    child: TextField(
                      controller: _descriptionController,
                      maxLines: null,
                      expands: true,
                      decoration: InputDecoration(
                        hintText: 'Type your description...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        contentPadding: EdgeInsets.all(12),
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                  _imageFile != null
                      ? Container(
                    height: 200,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        _imageFile!,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                  )
                      : Container(
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey),
                    ),
                    child: Center(child: Text("No image selected")),
                  ),
                  SizedBox(height: 20),
                  Center(
                    child: ElevatedButton.icon(
                      onPressed: _pickImage,
                      icon: Icon(Icons.image),
                      label: Text("Pick Image"),
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  Center(
                    child: ElevatedButton(
                      onPressed: _isUploading ? null : _uploadOrder,
                      child:
                      _isUploading
                          ? CircularProgressIndicator(color: Colors.white)
                          : Text("Post"),
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 100),
                ],
              ),
            ),
          ),

          if (_showSuccessAnimation)
            Center(
              child: AnimatedOpacity(
                duration: Duration(milliseconds: 500),
                opacity: _showSuccessAnimation ? 1.0 : 0.0,
                child: Container(
                  padding: EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 80),
                      SizedBox(height: 12),
                      Text(
                        "Order placed successfully!",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700],
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        "Order ID: $_generatedOrderId",
                        style: TextStyle(fontSize: 16, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
