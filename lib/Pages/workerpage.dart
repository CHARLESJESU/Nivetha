import 'dart:convert';
import 'dart:io';
import 'package:get/get.dart';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nivetha123/screens/user_data.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../login/Login.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'Backcontroll.dart';

class Workerpage extends StatefulWidget {
  final UserData userData;

  const Workerpage({Key? key, required this.userData}) : super(key: key);

  @override
  _WorkerpageState createState() => _WorkerpageState();
}

class _WorkerpageState extends State<Workerpage> {
  late UserData userData;


  List<Post> posts = [];
  bool isLoading = true;

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
      setState(() {
        isLoading = false;
      });
    }
  }
  //
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


  Future<void> _applyForJob(String jobProviderUserId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please log in to apply for jobs")),
      );
      return;
    }

    try {
      final workerUserId =
          userData.userId; // Using userData.userId instead of Firebase UID

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

      // Save worker details using the userData.userId as the worker's unique ID
      final applicationRef = FirebaseDatabase.instance
          .ref('applications')
          .child(jobProviderUserId) // The job provider's user ID
          .child(workerUserId); // The worker's userId from userData

      await applicationRef.set(workerDetails);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Successfully applied to the job!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to apply to the job: $e')));
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
                _buildProfileDetail('Experience', userData.experience),
            ],
          ),
        ),
        body:
            isLoading
                ? Center(child: CircularProgressIndicator())
                : ListView.builder(
                  itemCount: posts.length,
                  itemBuilder: (context, index) {
                    final post = posts[index];
                    return Card(
                      margin: EdgeInsets.all(8.0),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Job Provider ID: ${post.userId}",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 10),
                            if (post.imageBase64.isNotEmpty)
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (_) => FullImagePage(
                                            imageBase64: post.imageBase64,
                                          ),
                                    ),
                                  );
                                },
                                child: Image.memory(
                                  base64Decode(post.imageBase64),
                                  height: 200,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            SizedBox(height: 10),
                            Text(post.description),
                            Align(
                              alignment: Alignment.centerRight,
                              child: ElevatedButton(
                                onPressed: () {
                                  _applyForJob(post.userId);
                                },
                                child: Text("Apply Now"),
                              ),
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

  Widget _buildProfileAvatar({required double radius}) {
    return CircleAvatar(
      backgroundImage:
          userData.profileImage != null && userData.profileImage!.isNotEmpty
              ? FileImage(File(userData.profileImage!))
              : AssetImage('assets/default_profile.png') as ImageProvider,
      radius: radius,
    );
  }

  Widget _buildProfileDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text('$label: '), Text(value)],
      ),
    );
  }
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

