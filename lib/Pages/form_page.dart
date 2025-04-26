import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class FormPage extends StatefulWidget {
  @override
  _FormPageState createState() => _FormPageState();
}

class _FormPageState extends State<FormPage> {
  File? _image;
  final picker = ImagePicker();
  final TextEditingController _descriptionController = TextEditingController();

  // Pick an image from the gallery
  Future<void> _pickImage() async {
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _image = File(picked.path));
    }
  }

  // Remove the selected image
  void _removeImage() {
    setState(() {
      _image = null;
    });
  }

  // Handle submission of data
  void _submitData() {
    if (_image != null && _descriptionController.text.isNotEmpty) {
      Navigator.pop(context, {
        'image': _image,
        'description': _descriptionController.text,
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Please select an image and enter a description"),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Create Post")),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Large description box (like a LinkedIn post)
            Container(
              height: 300, // Large height for the description box
              width: double.infinity, // Full width
              child: TextField(
                controller: _descriptionController,
                maxLines: 20, // Allows the text field to expand vertically
                keyboardType: TextInputType.multiline,
                decoration: InputDecoration(
                  hintText: "What's on your mind?",
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            SizedBox(height: 100),

            // Center the image picker icon
            Center(
              child: GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 100, // Fixed size for the image picker
                  width: 100, // Fixed size for the image picker
                  color: Colors.grey[300],
                  child:
                      _image != null
                          ? Stack(
                            children: [
                              Image.file(_image!, fit: BoxFit.cover),
                              Positioned(
                                top: 10,
                                right: 10,
                                child: IconButton(
                                  icon: Icon(
                                    Icons.remove_circle,
                                    color: Colors.red,
                                  ),
                                  onPressed: _removeImage,
                                ),
                              ),
                            ],
                          )
                          : Icon(
                            Icons.camera_alt,
                            size: 50,
                            color: Colors.grey[700],
                          ),
                ),
              ),
            ),
            SizedBox(height: 100),

            // Submit button at the bottom
            Center(
              child: ElevatedButton(
                onPressed: _submitData,
                child: Text("Post"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
