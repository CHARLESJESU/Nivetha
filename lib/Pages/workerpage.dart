import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nivetha123/screens/user_data.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../login/Login.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
  Set<String> appliedJobIds = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    userData = widget.userData;
    _initializePreferences();
    _loadPosts();
    _loadAppliedJobs();
  }

  void _initializePreferences() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', true);
    await prefs.setBool('isworker', true);
  }

  Future<void> _loadAppliedJobs() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final ref = FirebaseDatabase.instance.ref('applications');
    final snapshot = await ref.get();

    if (snapshot.exists) {
      final data = snapshot.value as Map<dynamic, dynamic>;
      Set<String> jobIds = {};
      data.forEach((jobProviderId, workersMap) {
        if (workersMap is Map<dynamic, dynamic>) {
          workersMap.forEach((workerId, details) {
            if (workerId == userData.userId) {
              jobIds.add(jobProviderId);
            }
          });
        }
      });
      setState(() {
        appliedJobIds = jobIds;
      });
    }
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
          builder: (context) {
            return AlertDialog(
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
            );
          },
        );
        if (shouldExit == true) {
          SystemNavigator.pop();
        }
      }
      return Future.value(false);
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

      setState(() {
        appliedJobIds.add(jobProviderUserId);
      });

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

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: Text(
            'Welcome, \${userData.name}',
            style: TextStyle(color: Colors.white, fontSize: 20),
          ),
          backgroundColor: Colors.blue,
          iconTheme: IconThemeData(color: Colors.black),
          leading: IconButton(
            icon: _buildProfileAvatar(radius: 20),
            onPressed: () {
              _scaffoldKey.currentState?.openDrawer();
            },
          ),
          toolbarHeight: 70, // Increased AppBar height
        ),
        drawer: Drawer(), // Your drawer content here...
        body:
            isLoading
                ? Center(child: CircularProgressIndicator())
                : ListView.builder(
                  itemCount: posts.length,
                  itemBuilder: (context, index) {
                    final post = posts[index];
                    final alreadyApplied = appliedJobIds.contains(post.userId);
                    return Card(
                      margin: EdgeInsets.all(8.0),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Job Provider ID: \${post.userId}",
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
                                onPressed:
                                    alreadyApplied
                                        ? null
                                        : () => _applyForJob(post.userId),
                                child: Text(
                                  alreadyApplied ? "Applied" : "Apply Now",
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

  Widget _buildProfileAvatar({required double radius}) {
    return CircleAvatar(
      backgroundImage:
          userData.profileImage != null && userData.profileImage!.isNotEmpty
              ? FileImage(File(userData.profileImage!))
              : AssetImage('assets/default_profile.png') as ImageProvider,
      radius: radius,
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

class FullImagePage extends StatelessWidget {
  final String imageBase64;

  const FullImagePage({Key? key, required this.imageBase64}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Full Image')),
      body: Center(child: Image.memory(base64Decode(imageBase64))),
    );
  }
}
