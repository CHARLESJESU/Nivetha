import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/user_data.dart';

class ProfileDetailsPage extends StatefulWidget {
  final UserData userData;

  const ProfileDetailsPage({Key? key, required this.userData})
    : super(key: key);

  @override
  _ProfileDetailsPageState createState() => _ProfileDetailsPageState();
}

class _ProfileDetailsPageState extends State<ProfileDetailsPage> {
  late UserData userData;
  final picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    userData = widget.userData;
  }

  Future<void> _pickImage() async {
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        userData.profileImage = picked.path;
      });
    }
  }

  Widget _buildEditableField(
    String label,
    String value,
    void Function(String) onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      child: TextFormField(
        initialValue: value,
        decoration: InputDecoration(labelText: label),
        onChanged: onChanged,
      ),
    );
  }

  Future<void> _saveProfile() async {
    // Determine path based on role
    final rolePath =
        userData.role.toLowerCase() == 'worker' ? 'workers' : 'jobproviders';

    // Save to Firebase under correct role path
    final DatabaseReference ref = FirebaseDatabase.instance
        .ref()
        .child('users')
        .child(rolePath)
        .child(userData.userId);

    await ref.set(userData.toJson());

    // Save to SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('userData', jsonEncode(userData.toJson()));

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Profile saved successfully')));

    Navigator.pop(context, userData);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Profile Details'),
        backgroundColor: Colors.blue,
      ),
      body: ListView(
        children: [
          const SizedBox(height: 16),
          Center(
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundImage:
                      userData.profileImage != null &&
                              userData.profileImage!.isNotEmpty
                          ? FileImage(File(userData.profileImage!))
                          : null,
                  child:
                      userData.profileImage == null ||
                              userData.profileImage!.isEmpty
                          ? Text(
                            userData.name.isNotEmpty
                                ? userData.name[0].toUpperCase()
                                : '?',
                            style: TextStyle(fontSize: 40, color: Colors.white),
                          )
                          : null,
                  backgroundColor: Colors.grey,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: _pickImage,
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.white,
                      child: Icon(Icons.edit, color: Colors.blueAccent),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _buildEditableField(
            'Name',
            userData.name,
            (val) => userData.name = val,
          ),
          _buildEditableField(
            'Phone',
            userData.phoneNumber,
            (val) => userData.phoneNumber = val,
          ),
          _buildEditableField(
            'Role',
            userData.role,
            (val) => userData.role = val,
          ),
          _buildEditableField(
            'Gender',
            userData.gender,
            (val) => userData.gender = val,
          ),
          _buildEditableField(
            'DOB',
            userData.dob?.toLocal().toString().split(' ')[0] ?? '',
            (val) => userData.dob = DateTime.tryParse(val),
          ),
          _buildEditableField(
            'Country',
            userData.country,
            (val) => userData.country = val,
          ),
          _buildEditableField(
            'State',
            userData.state,
            (val) => userData.state = val,
          ),
          _buildEditableField(
            'District',
            userData.district,
            (val) => userData.district = val,
          ),
          _buildEditableField(
            'City',
            userData.city,
            (val) => userData.city = val,
          ),
          _buildEditableField(
            'Area',
            userData.area,
            (val) => userData.area = val,
          ),
          _buildEditableField(
            'Address',
            userData.address,
            (val) => userData.address = val,
          ),
          if (userData.role.toLowerCase() == 'worker')
            _buildEditableField(
              'Experience',
              userData.experience ?? '',
              (val) => userData.experience = val,
            ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ElevatedButton(
              onPressed: _saveProfile,
              child: Text('Save Changes'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            ),
          ),
        ],
      ),
    );
  }
}
