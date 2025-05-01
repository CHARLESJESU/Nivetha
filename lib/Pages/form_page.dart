import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';

class FormPage extends StatefulWidget {
  final String userId;

  FormPage({required this.userId});

  @override
  _FormPageState createState() => _FormPageState();
}

class _FormPageState extends State<FormPage> {
  File? _imageFile;
  final TextEditingController _descriptionController = TextEditingController();
  final DatabaseReference _dbRef = FirebaseDatabase.instance
      .ref()
      .child('jobs')
      .child('workers');
  bool _isUploading = false;

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _imageFile = File(picked.path);
      });
    }
  }

  Future<String> _convertImageToBase64(File imageFile) async {
    try {
      List<int> imageBytes = await imageFile.readAsBytes();
      return base64Encode(imageBytes);
    } catch (e) {
      print("Image conversion failed: $e");
      return '';
    }
  }

  Future<void> _uploadOrder() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("User not logged in")));
      return;
    }

    if (_imageFile == null || _descriptionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Please select an image and enter a description"),
        ),
      );
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      final userId = widget.userId;

      final base64Image = await _convertImageToBase64(_imageFile!);

      // ✅ Save multiple jobs using .push()
      await _dbRef.child(userId).push().set({
        'description': _descriptionController.text,
        'imageBase64': base64Image,
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Job posted successfully!")));

      Navigator.pop(context); // Return to previous screen
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to post job: $e")));
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Post Job")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: InputDecoration(labelText: 'Enter Description'),
              ),
              SizedBox(height: 16),
              _imageFile != null
                  ? Image.file(_imageFile!, height: 200)
                  : Container(
                    height: 200,
                    color: Colors.grey[300],
                    child: Center(child: Text("No image selected")),
                  ),
              SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _pickImage,
                icon: Icon(Icons.image),
                label: Text("Pick Image"),
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: _isUploading ? null : _uploadOrder,
                child:
                    _isUploading
                        ? CircularProgressIndicator(color: Colors.white)
                        : Text("Post"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
