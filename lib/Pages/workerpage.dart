import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../login/Login.dart';
import '../screens/user_data.dart';

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
      Get.snackbar('Exit', 'Press back again to confirm exit');
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
      Get.snackbar("Error", "Please log in to apply for jobs");
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
      Get.snackbar("Success", "Successfully applied to the job!");
    } catch (e) {
      Get.snackbar("Error", "Failed to apply to the job: $e");
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
          title: Text(
            'Welcome, ${userData.name}',
            style: TextStyle(fontWeight: FontWeight.bold),
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
                : ListView.builder(
                  itemCount: posts.length,
                  itemBuilder: (context, index) {
                    final post = posts[index];
                    final isApplied = appliedJobs[post.postId] ?? false;
                    return Card(
                      margin: EdgeInsets.all(12.0),
                      elevation: 8,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Job Provider ID: ${post.userId}",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blueAccent,
                              ),
                            ),
                            SizedBox(height: 10),
                            if (post.imageBase64.isNotEmpty)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.memory(
                                  base64Decode(post.imageBase64),
                                  height: 200,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            SizedBox(height: 10),
                            Text(
                              post.description,
                              style: TextStyle(fontSize: 16),
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: ElevatedButton(
                                onPressed:
                                    isApplied
                                        ? null
                                        : () => _applyForJob(
                                          post.userId,
                                          post.postId,
                                        ),
                                child: Text(
                                  isApplied ? "Applied" : "Apply Now",
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      isApplied
                                          ? Colors.grey
                                          : Colors.blueAccent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
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
