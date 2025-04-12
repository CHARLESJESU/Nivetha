import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:nivetha123/screens/summary.dart';
import 'package:nivetha123/screens/user_data.dart';

import '../widgets/step_progress.dart';

class Page4ProfileDetails extends StatefulWidget {
  final UserData userData;
  Page4ProfileDetails({required this.userData});

  @override
  _Page4ProfileDetailsState createState() => _Page4ProfileDetailsState();
}

class _Page4ProfileDetailsState extends State<Page4ProfileDetails> {
  File? _image;
  TextEditingController experienceController = TextEditingController();
  String? errorMessage;

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
    );
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
        widget.userData.profileImage = pickedFile.path;
      });
    }
  }

  void _validateAndProceed() {
    if (_image == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please upload a profile picture!')),
      );
      return;
    }

    if (experienceController.text.isEmpty) {
      setState(() {
        errorMessage = "Please enter your years of experience.";
      });
      return;
    }

    widget.userData.experience = experienceController.text;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Page5Summary(userData: widget.userData),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          'Profile Info',
          style: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.blue,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  StepProgress(currentStep: 4, totalSteps: 5),

                  SizedBox(height: 30),

                  // 📸 Profile Picture Upload
                  Text(
                    'Upload Profile Picture',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 15),
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      padding: EdgeInsets.all(4), // Border thickness
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.black,
                          width: 1,
                        ), // Black border
                      ),
                      child: CircleAvatar(
                        radius: 65,
                        backgroundColor: Colors.grey[200],
                        backgroundImage:
                            _image != null ? FileImage(_image!) : null,
                        child:
                            _image == null
                                ? Icon(
                                  Icons.camera_alt,
                                  size: 35,
                                  color: Colors.blue,
                                )
                                : null,
                      ),
                    ),
                  ),

                  SizedBox(height: 30),

                  // 🏆 Experience Input Field
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Years of Experience',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(height: 10),

                  TextField(
                    controller: experienceController,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.grey[200],
                      border: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: Colors.black,
                          width: 2,
                        ), // Black border
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        vertical: 15,
                        horizontal: 15,
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      setState(() {
                        errorMessage = null;
                      });
                    },
                  ),

                  if (errorMessage != null)
                    Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        errorMessage!,
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // 🔄 Fixed Navigation Buttons at Bottom
          Padding(
            padding: EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: EdgeInsets.symmetric(vertical: 15),
                    ),
                    child: Text('Back', style: TextStyle(color: Colors.white)),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _validateAndProceed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: EdgeInsets.symmetric(vertical: 15),
                    ),
                    child: Text('Next', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
