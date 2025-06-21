import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../login/Login.dart';
import '../screens/user_data.dart';
import 'Backcontroll.dart';
import 'job_status_page.dart';

class Workerpage extends StatefulWidget {
  final UserData userData;
  const Workerpage({Key? key, required this.userData}) : super(key: key);

  @override
  _WorkerpageState createState() => _WorkerpageState();
}

class _WorkerpageState extends State<Workerpage> {
  late UserData userData;
  int _selectedIndex = 0;
  Map<String, bool> appliedJobs = {};
  List<Post> posts = [];
  bool isLoading = true;

  String selectedDistrict = 'All';
  List<String> availableDistricts = ['All'];

  @override
  void initState() {
    super.initState();
    userData = widget.userData;
    _initializePreferences();
    _loadAppliedJobs();
    _loadPosts();
  }

  void _initializePreferences() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', true);
    await prefs.setBool('isworker', true);
    await prefs.setString('userData', jsonEncode(widget.userData.toJson()));
  }

  Future<void> _loadAppliedJobs() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> appliedPostIds = prefs.getStringList('appliedJobIds') ?? [];
    setState(() {
      appliedJobs = {for (var id in appliedPostIds) id: true};
    });
  }

  Future<void> _saveAppliedJob(String postId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> current = prefs.getStringList('appliedJobIds') ?? [];
    if (!current.contains(postId)) {
      current.add(postId);
      await prefs.setStringList('appliedJobIds', current);
    }
  }

  Future<void> _loadPosts() async {
    try {
      final postsRef = FirebaseDatabase.instance.ref().child('jobs/workers');
      final snapshot = await postsRef.get();
      List<Post> fetchedPosts = [];
      Set<String> districtSet = {};

      if (snapshot.exists) {
        final workersData = Map<String, dynamic>.from(snapshot.value as Map);
        workersData.forEach((userId, postsData) {
          final postList = Map<String, dynamic>.from(postsData);
          postList.forEach((key, value) {
            final postData = Map<String, dynamic>.from(value);
            final district = postData['district'] ?? 'Unknown';
            districtSet.add(district);
            fetchedPosts.add(
              Post(
                userId: userId,
                postId: key,
                description: postData['description'] ?? '',
                imageBase64: postData['imageBase64'] ?? '',
                orderId: postData['orderId'] ?? '',
                district: district,
              ),
            );
          });
        });
      }

      fetchedPosts.sort((a, b) => b.postId.compareTo(a.postId));

      setState(() {
        posts = fetchedPosts;
        isLoading = false;
        availableDistricts = ['All', ...districtSet.toList()..sort()];
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
    if (image != null) {
      setState(() {
        userData.profileImage = image.path;
      });
    }
  }

  Future<void> _applyForJob(String jobProviderUserId, String postId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Please log in to apply")));
      return;
    }

    try {
      final post = posts.firstWhere(
        (p) => p.postId == postId && p.userId == jobProviderUserId,
        orElse: () => Post.empty(),
      );

      if (post.postId.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Post not found")));
        return;
      }

      final workerDetails = {
        'workerUserId': userData.userId,
        'name': userData.name,
        'phoneNumber': userData.phoneNumber,
        'experience': userData.experience ?? 'Not provided',
        'role': userData.role,
        'gender': userData.gender,
        'dob': userData.dob?.toIso8601String() ?? '',
        'country': userData.country,
        'state': userData.state,
        'district': userData.district,
        'city': userData.city,
        'area': userData.area,
        'address': userData.address,
      };

      await FirebaseDatabase.instance
          .ref('applications/$jobProviderUserId/$postId/${userData.userId}')
          .set(workerDetails);

      await FirebaseDatabase.instance
          .ref('appliedJobs/${userData.userId}/$jobProviderUserId/$postId')
          .set({
            'orderId': post.orderId,
            'description': post.description,
            'imageBase64': post.imageBase64,
            'status': 'applied',
            'appliedAt': DateTime.now().toIso8601String(),
          });

      setState(() => appliedJobs[postId] = true);
      await _saveAppliedJob(postId);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Applied successfully!")));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Apply failed: $e")));
    }
  }

  Widget buildDrawer() {
    return Drawer(
      child: ListView(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: Colors.blueAccent),
            child: Text(
              "Hello, ${userData.name}",
              style: TextStyle(color: Colors.white, fontSize: 20),
            ),
          ),
          ListTile(
            leading: Icon(Icons.logout),
            title: Text("Logout"),
            onTap: () {
              FirebaseAuth.instance.signOut();
              Get.offAll(() => LoginScreen());
            },
          ),
        ],
      ),
    );
  }

  Widget _buildProfileAvatar({double radius = 20}) {
    final imageFile = userData.profileImage;
    return CircleAvatar(
      radius: radius,
      backgroundImage:
          imageFile != null &&
                  imageFile.isNotEmpty &&
                  File(imageFile).existsSync()
              ? FileImage(File(imageFile))
              : AssetImage('assets/default_avatar.png') as ImageProvider,
    );
  }

  Widget _buildMainContent() {
    return _selectedIndex == 0
        ? buildJobPosts()
        : JobStatusPage(userData: userData);
  }

  Widget buildJobPosts() {
    final filtered =
        selectedDistrict == 'All'
            ? posts
            : posts.where((p) => p.district == selectedDistrict).toList();

    return isLoading
        ? Center(child: CircularProgressIndicator())
        : filtered.isEmpty
        ? Center(child: Text("No jobs available."))
        : Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: DropdownButton<String>(
                value: selectedDistrict,
                isExpanded: true,
                items:
                    availableDistricts
                        .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                        .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => selectedDistrict = v);
                },
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: filtered.length,
                itemBuilder: (context, i) {
                  final post = filtered[i];
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
                          Text(
                            "Job Provider ID: ${post.userId}",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blueAccent,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text("District: ${post.district}"),
                          SizedBox(height: 6),
                          if (post.imageBase64.isNotEmpty)
                            Image.memory(
                              base64Decode(post.imageBase64),
                              height: 100,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          SizedBox(height: 8),
                          Text(post.description),
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
                              icon: Icon(Icons.send),
                              label: Text(isApplied ? 'Applied' : 'Apply Now'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
  }

  @override
  Widget build(BuildContext context) {
    final backController = Get.put(BackButtonController());
    final scaffoldKey = GlobalKey<ScaffoldState>();

    return WillPopScope(
      onWillPop: backController.handleWillPop,
      child: Scaffold(
        key: scaffoldKey,
        appBar: AppBar(
          title: Text(
            _selectedIndex == 0 ? 'Welcome, ${userData.name}' : 'Job Status',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.blueAccent,
          leading: IconButton(
            icon: _buildProfileAvatar(radius: 18),
            onPressed: () => scaffoldKey.currentState?.openDrawer(),
          ),
        ),
        drawer: buildDrawer(),
        body: _buildMainContent(),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (i) => setState(() => _selectedIndex = i),
          selectedItemColor: Colors.blueAccent,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(
              icon: Icon(Icons.assignment),
              label: 'Job Status',
            ),
          ],
        ),
      ),
    );
  }
}

class Post {
  final String userId;
  final String postId;
  final String description;
  final String imageBase64;
  final String orderId;
  final String district;

  Post({
    required this.userId,
    required this.postId,
    required this.description,
    required this.imageBase64,
    required this.orderId,
    required this.district,
  });

  factory Post.empty() => Post(
    userId: '',
    postId: '',
    description: '',
    imageBase64: '',
    orderId: '',
    district: '',
  );
}
