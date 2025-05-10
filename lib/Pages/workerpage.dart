import 'dart:convert';
import 'dart:io';
import 'package:get/get.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../login/Login.dart';
import '../screens/user_data.dart';

import 'Backcontroll.dart';

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




  List<Post> posts = [];
  bool isLoading = true;
  Map<String, bool> appliedJobs = {};

  @override
  void initState() {
    super.initState();
    userData = widget.userData;
    _initializePreferences();
    _loadPosts();
  }

  void _initializePreferences() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', true);
    await prefs.setBool('isworker', true);
  }

  Future<void> _loadPosts() async {
    try {
      final postsRef = FirebaseDatabase.instance.ref().child('jobs/workers');
      final snapshot = await postsRef.get();
      List<Post> fetchedPosts = [];
      if (snapshot.exists) {
        final workersData = snapshot.value as Map<dynamic, dynamic>;
        workersData.forEach((userId, postsData) {
          if (postsData is Map<dynamic, dynamic>) {
            postsData.forEach((key, value) {
              if (value is Map<dynamic, dynamic>) {
                fetchedPosts.add(
                  Post(
                    userId: userId,
                    postId: key,
                    description: value['description'] ?? '',
                    imageBase64: value['imageBase64'] ?? '',
                  ),
                );
              }
            });
          }
        });
      }
      fetchedPosts.sort((a, b) => b.postId.compareTo(a.postId));
      setState(() {
        posts = fetchedPosts;
        isLoading = false;
      });
    } catch (e) {
      print("Failed to load posts: $e");
      setState(() => isLoading = false);
    }
  }
  //
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
    if (image != null) setState(() => userData.profileImage = image.path);
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
        bool? shouldExit = await Get.dialog(
          AlertDialog(
            title: Text('Exit App'),
            content: Text('Are you sure you want to exit?'),
            actions: [
              TextButton(
                onPressed: () => Get.back(result: false),
                child: Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Get.back(result: true),
                child: Text('Exit'),
              ),
            ],
          ),
        );
        if (shouldExit == true) SystemNavigator.pop();
      }
      return Future.value(false);
    }
  }


  Future<void> _applyForJob(String jobProviderUserId, String postId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please log in to apply for jobs")),
      );
      return;
    }
    try {
      final workerUserId = userData.userId;
      final workerDetails = {
        'workerUserId': workerUserId,
        'name': userData.name,
        'phoneNumber': userData.phoneNumber,
        'experience': userData.experience ?? 'Not provided',
        'role': userData.role,
        'gender': userData.gender,
        'dob': userData.dob?.toLocal().toString().split(' ')[0] ?? 'Not Set',
        'country': userData.country,
        'state': userData.state,
        'district': userData.district,
        'city': userData.city,
        'area': userData.area,
        'address': userData.address,
      };
      final applicationRef = FirebaseDatabase.instance
          .ref('applications')
          .child(jobProviderUserId)
          .child(workerUserId);
      await applicationRef.set(workerDetails);
      setState(() => appliedJobs[postId] = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Successfully applied to the job!")),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to apply to the job: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

    final BackButtonController backController = Get.put(BackButtonController());



    return WillPopScope(
      onWillPop: backController.handleWillPop,
      child: Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          title: Text(
            'Welcome, ${userData.name}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: 25,
            ),
          ),
          backgroundColor: Colors.blueAccent,
          leading: IconButton(
            icon: _buildProfileAvatar(radius: 20),
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
        ),
        drawer: Drawer(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              UserAccountsDrawerHeader(
                accountName: Text(
                  userData.name,
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
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
                          child: Icon(
                            Icons.edit,
                            size: 18,
                            color: Colors.blueAccent,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                decoration: BoxDecoration(color: Colors.blueAccent),
              ),
              ListTile(
                leading: Icon(Icons.logout),
                title: Text('Logout'),
                onTap: () async {

                  bool? shouldLogout = await Get.dialog(
                    AlertDialog(
                      title: Text("Confirm Logout"),
                      content: Text("Are you sure you want to logout?"),
                      actions: [
                        TextButton(
                          onPressed: () => Get.back(result: false),
                          child: Text("Cancel"),
                        ),
                        TextButton(
                          onPressed: () => Get.back(result: true),
                          child: Text("Confirm"),
                        ),
                      ],
                    ),
                  );
                  if (shouldLogout == true) {
                    SharedPreferences prefs =
                        await SharedPreferences.getInstance();
                    await prefs.setBool('isLoggedIn', false);
                    Get.offAll(() => LoginScreen());
                  }

                  Get.defaultDialog(
                    title: "Confirm Logout",
                    middleText: "Are you sure you want to logout?",
                    textCancel: "Cancel",
                    textConfirm: "Confirm",
                    onConfirm: () async {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('isLoggedIn', false);
                      Get.offAll(() => const LoginScreen());
                    },
                    onCancel: () {},
                  );

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
                _buildProfileDetail('Experience', userData.experience ?? ''),
            ],
          ),
        ),
        body:
            isLoading
                ? Center(child: CircularProgressIndicator())
                : posts.isEmpty
                ? Center(child: Text("No jobs available."))
                : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: posts.length,
                  itemBuilder: (context, index) {
                    final post = posts[index];
                    final isApplied = appliedJobs[post.postId] ?? false;

                    return Card(
                      color: Color(0xFFF2F2F2),
                      margin: const EdgeInsets.only(bottom: 16),
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(
                                left: 4,
                                bottom: 8,
                              ),
                              child: Text(
                                "Job Provider Id: ${post.userId}",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blueAccent,
                                ),
                              ),
                            ),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (post.imageBase64.isNotEmpty)
                                  GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder:
                                              (_) => Scaffold(
                                                appBar: AppBar(
                                                  backgroundColor: Colors.black,
                                                  iconTheme: IconThemeData(
                                                    color: Colors.white,
                                                  ),
                                                ),
                                                backgroundColor: Colors.black,
                                                body: Center(
                                                  child: InteractiveViewer(
                                                    child: Image.memory(
                                                      base64Decode(
                                                        post.imageBase64,
                                                      ),
                                                      fit: BoxFit.contain,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                        ),
                                      );
                                    },
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: Image.memory(
                                        base64Decode(post.imageBase64),
                                        height: 100,
                                        width: 100,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        post.description,
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      SizedBox(height: 12),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: ElevatedButton.icon(
                                          onPressed:
                                              isApplied
                                                  ? null
                                                  : () => _applyForJob(
                                                    post.userId,
                                                    post.postId,
                                                  ),
                                          icon: Icon(
                                            Icons.work,
                                            color: Colors.white,
                                          ),
                                          label: Text(
                                            isApplied ? "Applied" : "Apply Now",
                                            style: TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                isApplied
                                                    ? Colors.grey
                                                    : Colors.blue,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 10,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      ),
    );
  }

  Widget _buildProfileAvatar({required double radius}) => CircleAvatar(
    backgroundImage:
        userData.profileImage != null && userData.profileImage!.isNotEmpty
            ? FileImage(File(userData.profileImage!))
            : AssetImage('assets/default_profile.png') as ImageProvider,
    radius: radius,
  );

  Widget _buildProfileDetail(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 16.0),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '$label:',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        Text(value, style: TextStyle(fontSize: 16)),
      ],
    ),
  );
}

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

