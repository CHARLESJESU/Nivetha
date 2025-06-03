import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nivetha123/screens/user_data.dart';
import '../login/Login.dart';
import 'form_page.dart';
import 'applications.dart';
import 'messages.dart';
import 'order_details.dart';

class Jobproviderpage extends StatefulWidget {
  final UserData userData;

  const Jobproviderpage({Key? key, required this.userData}) : super(key: key);

  @override
  _JobproviderpageState createState() => _JobproviderpageState();
}

class _JobproviderpageState extends State<Jobproviderpage> {
  late UserData userData;
  int _selectedIndex = 0;
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
    await prefs.setBool('isworker', false);
    await prefs.setString('userData', jsonEncode(widget.userData.toJson()));
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final XFile? image = await showModalBottomSheet<XFile?>(
      context: context,
      builder:
          (context) => SafeArea(
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
          ),
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
          SystemNavigator.pop();
        }
      }
      return Future.value(false);
    }
  }

  Widget _buildSelectedPage() {
    switch (_selectedIndex) {
      case 0:
        return OrderDetailsPage(userId: widget.userData.userId);
      case 1:
        return ApplicationsPage(jobProviderUserId: userData.userId);
      case 2:
        return MessagesPage();
      default:
        return OrderDetailsPage(userId: widget.userData.userId);
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
          title: Text('${userData.name}'),
          backgroundColor: Colors.blue,
          leading: IconButton(
            icon: _buildProfileAvatar(radius: 20),
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
        ),
        drawer: _buildDrawer(),
        body: Stack(
          children: [
            _buildSelectedPage(),
            if (_selectedIndex == 0)
              Positioned(
                bottom: 16,
                right: 16,
                child: FloatingActionButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (_) => FormPage(userId: widget.userData.userId),
                      ),
                    );
                  },
                  child: Icon(Icons.add),
                  backgroundColor: Colors.blue,
                ),
              ),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) => setState(() => _selectedIndex = index),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.list), label: 'Orders'),
            BottomNavigationBarItem(
              icon: Icon(Icons.assignment_ind),
              label: 'Applications',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.message),
              label: 'Messages',
            ),
          ],
        ),
      ),
    );
  }

  Drawer _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            color: Colors.blue,
            padding: EdgeInsets.symmetric(vertical: 30),
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.grey[200],
                      radius: 40,
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
                                style: TextStyle(
                                  fontSize: 40,
                                  color: Colors.blue,
                                ),
                              )
                              : null,
                    ),
                    Positioned(
                      child: CircleAvatar(
                        backgroundColor: Colors.white,
                        radius: 12,
                        child: Icon(Icons.edit, size: 15, color: Colors.blue),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  userData.name,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  userData.phoneNumber,
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
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
                        onPressed: () => Navigator.of(context).pop(false),
                        child: Text("Cancel"),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: Text("Confirm"),
                      ),
                    ],
                  );
                },
              );

              if (shouldLogout == true) {
                SharedPreferences prefs = await SharedPreferences.getInstance();
                await prefs.setBool('isLoggedIn', false);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
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
      backgroundColor: Colors.grey[300],
      radius: radius,
      child: Text(
        userData.name.isNotEmpty ? userData.name[0].toUpperCase() : '?',
        style: TextStyle(fontSize: radius, color: Colors.blue),
      ),
    );
  }
}
