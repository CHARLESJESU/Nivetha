import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:nivetha123/screens/user_data.dart';
import 'package:nivetha123/screens/checkbox_animation_page.dart';
import '../widgets/step_progress.dart';

class Page5Summary extends StatefulWidget {
  final UserData userData;

  const Page5Summary({Key? key, required this.userData}) : super(key: key);

  @override
  _Page5SummaryState createState() => _Page5SummaryState();
}

class _Page5SummaryState extends State<Page5Summary> {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  String generatedUserId = '';
  bool isUserIdLoading = false;
  bool termsAccepted = false;

  Future<String> _generateUniqueUserId(String role) async {
    final lastIdRef = _database.child('lastUserId');
    final lastIdSnapshot = await lastIdRef.get();

    int lastId = 1000;

    if (lastIdSnapshot.exists) {
      try {
        if (lastIdSnapshot.value is int) {
          lastId = lastIdSnapshot.value as int;
        } else if (lastIdSnapshot.value is String) {
          lastId = int.parse(lastIdSnapshot.value as String);
        }
      } catch (e) {
        print("Failed to parse lastUserId: $e");
      }
    }

    final newId = lastId + 1;
    await lastIdRef.set(newId);

    final prefix = role == 'Worker' ? 'WO' : 'JO';
    return '$prefix${newId.toString().padLeft(4, '0')}';
  }

  Future<String?> _convertImageToBase64(String imagePath) async {
    try {
      File imageFile = File(imagePath);
      List<int> imageBytes = await imageFile.readAsBytes();
      return base64Encode(imageBytes);
    } catch (e) {
      print("Image conversion failed: $e");
      return null;
    }
  }

  Future<void> _handleSubmit() async {
    if (!termsAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please accept Terms & Conditions')),
      );
      return;
    }

    try {
      setState(() {
        isUserIdLoading = true;
      });

      generatedUserId = await _generateUniqueUserId(widget.userData.role);

      String? base64Image;
      if (widget.userData.role == 'Worker' &&
          widget.userData.profileImage != null &&
          widget.userData.profileImage!.isNotEmpty) {
        base64Image = await _convertImageToBase64(
          widget.userData.profileImage!,
        );
      }

      Map<String, dynamic> userDataMap = {
        "userId": generatedUserId,
        "name": widget.userData.name,
        "role": widget.userData.role,
        "gender": widget.userData.gender,
        "dob": widget.userData.dob?.toIso8601String() ?? "Not Set",
        "phone": widget.userData.phoneNumber,
        "country": widget.userData.country,
        "state": widget.userData.state,
        "district": widget.userData.district,
        "city": widget.userData.city,
        "area": widget.userData.area,
        "address": widget.userData.address,
        "experience":
            widget.userData.role == 'Worker'
                ? widget.userData.experience
                : "N/A",
        "profileImageBase64": base64Image ?? "No Image",
      };

      await _database.child("users").push().set(userDataMap);

      setState(() {
        isUserIdLoading = false;
      });

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder:
              (context) => CheckboxAnimationPage(
                success: true,
                userData: widget.userData,
              ),
        ),
      );
    } catch (e) {
      setState(() {
        isUserIdLoading = false;
      });
      print("Submit Error: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Submit failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile Overview'),
        backgroundColor: Colors.blue,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StepProgress(currentStep: 5, totalSteps: 5),
            const SizedBox(height: 20),
            const Text(
              'Review Your Details',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(),

            if (widget.userData.role == 'Worker')
              Center(
                child: CircleAvatar(
                  radius: 65,
                  backgroundImage:
                      widget.userData.profileImage != null
                          ? FileImage(File(widget.userData.profileImage!))
                          : null,
                  child:
                      widget.userData.profileImage == null
                          ? const Icon(
                            Icons.person,
                            size: 65,
                            color: Colors.blue,
                          )
                          : null,
                ),
              ),

            if (generatedUserId.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Center(child: Text('User ID')),
              Center(
                child: Text(
                  generatedUserId,
                  style: const TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 25),
            _buildInfoRow('Name:', widget.userData.name),
            _buildInfoRow('Role:', widget.userData.role),
            _buildInfoRow('Gender:', widget.userData.gender),
            _buildInfoRow(
              'DOB:',
              widget.userData.dob?.toLocal().toString().split(' ')[0] ??
                  "Not Set",
            ),
            _buildInfoRow('Phone:', widget.userData.phoneNumber),
            _buildInfoRow('Country:', widget.userData.country),
            _buildInfoRow('State:', widget.userData.state),
            _buildInfoRow('District:', widget.userData.district),
            _buildInfoRow('City:', widget.userData.city),
            _buildInfoRow('Area:', widget.userData.area),
            _buildInfoRow('Address:', widget.userData.address),

            if (widget.userData.role == 'Worker')
              _buildInfoRow('Experience:', widget.userData.experience),

            const SizedBox(height: 20),
            CheckboxListTile(
              value: termsAccepted,
              onChanged: (value) {
                setState(() {
                  termsAccepted = value ?? false;
                });
              },
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text('I accept the Terms & Conditions'),
              activeColor: Colors.blue,
            ),
            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Back'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: isUserIdLoading ? null : _handleSubmit,
                    child:
                        isUserIdLoading
                            ? const CircularProgressIndicator(
                              color: Colors.white,
                            )
                            : const Text('Submit'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          (termsAccepted && !isUserIdLoading)
                              ? Colors.blue
                              : Colors.grey,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Text('$label ', style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value.isNotEmpty ? value : 'Not provided')),
        ],
      ),
    );
  }
}
