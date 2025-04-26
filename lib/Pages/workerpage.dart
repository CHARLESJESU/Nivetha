import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nivetha123/screens/user_data.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../login/Login.dart';

class Workerpage extends StatefulWidget {
  final UserData userData;

  const Workerpage({Key? key, required this.userData}) : super(key: key);

  @override
  _WorkerpageState createState() => _WorkerpageState();
}

class _WorkerpageState extends State<Workerpage> {
  late UserData userData;
  int _backPressCounter = 0;
  DateTime? _lastBackPressed;

  @override
  void initState() {
    super.initState();
    userData = widget.userData;
    _initializePreferences();
  }

  void _initializePreferences() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', true);
    await prefs.setBool('isworker', true);
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final XFile? image = await showModalBottomSheet<XFile?>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: Icon(Icons.camera_alt),
                title: Text('Take Photo'),
                onTap: () async {
                  final picked = await picker.pickImage(
                    source: ImageSource.camera,
                  );
                  Navigator.pop(context, picked);
                },
              ),
              ListTile(
                leading: Icon(Icons.photo_library),
                title: Text('Choose from Gallery'),
                onTap: () async {
                  final picked = await picker.pickImage(
                    source: ImageSource.gallery,
                  );
                  Navigator.pop(context, picked);
                },
              ),
            ],
          ),
        );
      },
    );

    if (image != null) {
      setState(() {
        userData.profileImage = image.path;
      });
    }
  }

  Future<bool> _onWillPop() async {
    DateTime now = DateTime.now();
    if (_lastBackPressed == null ||
        now.difference(_lastBackPressed!) > Duration(seconds: 2)) {
      _lastBackPressed = now;
      _backPressCounter = 1;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Press back again to confirm exit')),
      );
      return Future.value(false);
    } else {
      _backPressCounter++;
      if (_backPressCounter >= 2) {
        final shouldExit = await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                title: Text('Exit App'),
                content: Text('Are you sure you want to exit?'),
                actions: [
                  TextButton(
                    child: Text('Cancel'),
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                  TextButton(
                    child: Text('Exit'),
                    onPressed: () => Navigator.of(context).pop(true),
                  ),
                ],
              ),
        );
        if (shouldExit == true) {
          SystemNavigator.pop(); // Exit app
        }
      }
      return Future.value(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          title: Text('Welcome, ${userData.name}'),
          backgroundColor: Colors.blue,
          leading: IconButton(
            icon: _buildProfileAvatar(radius: 20),
            onPressed: () {
              _scaffoldKey.currentState?.openDrawer();
            },
          ),
        ),
        drawer: Drawer(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              UserAccountsDrawerHeader(
                accountName: Text(userData.name),
                accountEmail: Text(userData.phoneNumber),
                currentAccountPicture: Stack(
                  children: [
                    _buildProfileAvatar(radius: 40),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          padding: EdgeInsets.all(3),
                          child: Icon(Icons.edit, size: 18, color: Colors.blue),
                        ),
                      ),
                    ),
                  ],
                ),
                decoration: BoxDecoration(color: Colors.blue),
              ),
              ListTile(
                leading: Icon(Icons.logout),
                title: Text('Logout'),
                onTap: () async {
                  bool shouldLogout = await showDialog(
                    context: context,
                    builder: (context) {
                      return AlertDialog(
                        title: Text("Confirm Logout"),
                        content: Text("Are you sure you want to logout?"),
                        actions: [
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop(false); // Cancel logout
                            },
                            child: Text("Cancel"),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop(true); // Confirm logout
                            },
                            child: Text("Confirm"),
                          ),
                        ],
                      );
                    },
                  );

                  if (shouldLogout == true) {
                    SharedPreferences prefs =
                        await SharedPreferences.getInstance();
                    await prefs.setBool('isLoggedIn', false);

                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LoginScreen(),
                      ),
                    );
                  }
                },
              ),
              Divider(),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Profile Details',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              _buildProfileDetail('User Id', userData.userId),
              _buildProfileDetail('Role', userData.role),
              _buildProfileDetail('Gender', userData.gender),
              _buildProfileDetail(
                'DOB',
                userData.dob?.toLocal().toString().split(' ')[0] ?? 'Not Set',
              ),
              _buildProfileDetail('Phone', userData.phoneNumber),
              _buildProfileDetail('Country', userData.country),
              _buildProfileDetail('State', userData.state),
              _buildProfileDetail('District', userData.district),
              _buildProfileDetail('City', userData.city),
              _buildProfileDetail('Area', userData.area),
              _buildProfileDetail('Address', userData.address),
              if (userData.role == 'Worker')
                _buildProfileDetail('Experience', userData.experience),
            ],
          ),
        ),
        body: Center(
          child: Text('Home Screen', style: TextStyle(fontSize: 18)),
        ),
      ),
    );
  }

  Widget _buildProfileDetail(String label, String value) {
    return ListTile(
      title: Text(label),
      subtitle: Text(value.isNotEmpty ? value : 'Not provided'),
    );
  }

  Widget _buildProfileAvatar({double radius = 20}) {
    if (userData.profileImage != null && userData.profileImage!.isNotEmpty) {
      return CircleAvatar(
        backgroundImage: FileImage(File(userData.profileImage!)),
        radius: radius,
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.grey[300],
      child: Text(
        userData.name.isNotEmpty ? userData.name[0].toUpperCase() : '?',
        style: TextStyle(fontSize: radius, color: Colors.blue),
      ),
    );
  }
}
