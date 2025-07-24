import 'dart:convert';

import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:flutter/material.dart';

import 'package:geocoding/geocoding.dart';

import 'package:get/get.dart';

import 'package:image_picker/image_picker.dart';

import 'package:firebase_database/firebase_database.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:nivetha123/Pages/workerpagesubfolder/contentviewer.dart';

import 'package:nivetha123/Pages/workerpagesubfolder/workerjobprovider.dart';

import 'package:nivetha123/Pages/workerpagesubfolder/workerpost.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../login/Login.dart';

import '../screens/user_data.dart';

import 'Backcontroll.dart';

import 'job_status_page.dart';

import 'map_pages.dart';

import 'profile_details_page.dart';


class Workerpage extends StatefulWidget {
  final UserData userData;
  const Workerpage({Key? key, required this.userData}) : super(key: key);

  @override
  _WorkerpageState createState() => _WorkerpageState();
}

class _WorkerpageState extends State<Workerpage> {
  late UserData userData;
  int _selectedIndex = 0;

  // These will be passed to WorkerContentView or managed centrally if more complex
  List<Post> posts = [];
  bool isLoading = true;
  Map<String, bool> appliedJobs = {};
  Map<String, JobProvider> jobProviderDetails = {};
  String? selectedCity;
  List<String> availableCities = [];


  @override
  void initState() {
    super.initState();
    userData = widget.userData;
    _initializePreferences();
    _loadAppliedJobs();
    _loadPosts(); // This will load data for both tabs
  }

  void _initializePreferences() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', true);
    await prefs.setBool('worker', true);
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
    setState(() => isLoading = true); // Set loading true at the start
    try {
      final workersRef = FirebaseFirestore.instance
          .collection('jobs')
          .doc('workers')
          .collection('workers');

      final workersSnapshot = await workersRef.get();
      List<Post> fetchedPosts = [];
      Map<String, JobProvider> fetchedJobProviders = {};
      Set<String> cities = {};

      for (final workerDoc in workersSnapshot.docs) {
        try {
          final userId = workerDoc.id;

          final ordersSnapshot = await workerDoc.reference
              .collection('order')
              .get();
          for (final orderDoc in ordersSnapshot.docs) {
            final data = orderDoc.data();
            fetchedPosts.add(
              Post(
                userId: userId,
                postId: orderDoc.id,
                description: data['description'] ?? '',
                imageBase64: data['imageBase64'] ?? '',
                orderId: data['orderkey'] ?? '',
              ),
            );
          }

          final providerSnapshot = await FirebaseFirestore.instance
              .collection('users')
              .doc('jobproviders')
              .collection('jobproviders')
              .doc(userId)
              .get();

          if (providerSnapshot.exists) {
            final data = providerSnapshot.data()!;
            final city = data['city'] ?? '';
            if (city.isNotEmpty) cities.add(city);

            fetchedJobProviders[userId] = JobProvider(
              name: data['name'] ?? '',
              gender: data['gender'] ?? '',
              dob: data['dob'] ?? '',
              email: data['email-id'] ?? '',
              phone: data['phone'] ?? '',
              address: data['address'] ?? '',
              area: data['area'] ?? '',
              city: city,
              district: data['district'] ?? '',
              state: data['state'] ?? '',
              country: data['country'] ?? '',
              experience: data['experience'] ?? '',
              role: data['role'] ?? '',
              profileImageBase64: data['profileImageBase64'] ?? '',
            );
          }
        } catch (e) {
          print("Error processing workerDoc ${workerDoc.id}: $e");
          continue; // Skip to next workerDoc
        }
      }

      fetchedPosts.sort((a, b) => b.postId.compareTo(a.postId));

      setState(() {
        posts = fetchedPosts;
        jobProviderDetails = fetchedJobProviders;
        isLoading = false;
        availableCities = cities.toList()..sort();
      });
    } catch (e) {
      print("Failed to load posts or providers: $e");
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to load jobs: $e")),
      );
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
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('userData', jsonEncode(userData.toJson()));
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc('workers')
            .collection('workers')
            .doc(userData.userId)
            .update({'profileImage': image.path});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Profile image updated successfully')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update profile image: $e')),
        );
      }
    }
  }

  Future<void> _applyForJob(String jobProviderUserId, String postId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please log in to apply for jobs")),
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

      final post = posts.firstWhere(
            (p) => p.postId == postId && p.userId == jobProviderUserId,
        orElse:
            () => Post(
          userId: '',
          postId: '',
          orderId: '',
          description: '',
          imageBase64: '',
        ),
      );

      if (post.postId.isEmpty || post.userId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Post not found or invalid")),
        );
        return;
      }

      final postRef = FirebaseFirestore.instance
          .collection('applications')
          .doc(jobProviderUserId)
          .collection('posts')
          .doc(postId);

      await postRef.set({'active': true}, SetOptions(merge: true));

      await postRef
          .collection('workers')
          .doc(workerUserId)
          .set(workerDetails);


      final appliedJobDetails = {
        'orderId': post.orderId,
        'description': post.description,
        'imageBase64': post.imageBase64,
        'status': 'applied',
        'appliedAt': DateTime.now().toIso8601String(),
      };

      final jobRef = FirebaseFirestore.instance
          .collection('appliedJobs')
          .doc(workerUserId)
          .collection('jobProviders')
          .doc(jobProviderUserId);

      await jobRef.set({'summa': 1}, SetOptions(merge: true));

      await jobRef
          .collection('posts')
          .doc(postId)
          .set(appliedJobDetails);

      setState(() => appliedJobs[postId] = true);
      await _saveAppliedJob(postId);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Successfully applied to the job!")),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to apply to the job: $e")));
    }
  }

  Widget _buildMainContent() {
    if (_selectedIndex == 0) {
      return WorkerContentView(
        posts: posts,
        isLoading: isLoading,
        appliedJobs: appliedJobs,
        jobProviderDetails: jobProviderDetails,
        selectedCity: selectedCity,
        availableCities: availableCities,
        onCityChanged: (city) => setState(() => selectedCity = city),
        onApplyForJob: _applyForJob,
        onRefreshPosts: _loadPosts, // Pass the refresh function down
      );
    } else {
      return JobStatusPage(userData: userData);
    }
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
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: 25,
            ),
          ),
          backgroundColor: Colors.blueAccent,
          leading: IconButton(
            icon: _buildProfileAvatar(radius: 20),
            onPressed: () => scaffoldKey.currentState?.openDrawer(),
          ),
        ),
        drawer: buildDrawer(),
        body: RefreshIndicator(
          onRefresh:_loadPosts,
          child: _buildMainContent(),
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedIndex,
          selectedItemColor: Colors.blueAccent,
          onTap: (index) => setState(() => _selectedIndex = index),
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

  Drawer buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            accountName: Text(
              userData.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            accountEmail: Text(userData.userId),
            currentAccountPicture: Stack(
              children: [
                _buildProfileAvatar(radius: 40),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(3), // Add padding for the icon
                      child: const Icon(
                        Icons.edit,
                        size: 24,
                        color: Colors.blueAccent,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            decoration: const BoxDecoration(color: Colors.blueAccent),
          ),
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('Profile Details'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProfileDetailsPage(userData: userData),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Logout'),
            onTap: () async {
              final shouldLogout = await Get.dialog(
                AlertDialog(
                  title: const Text("Confirm Logout"),
                  content: const Text("Are you sure you want to logout?"),
                  actions: [
                    TextButton(
                      onPressed: () => Get.back(result: false),
                      child: const Text("Cancel"),
                    ),
                    TextButton(
                      onPressed: () => Get.back(result: true),
                      child: const Text("Confirm"),
                    ),
                  ],
                ),
              );
              if (shouldLogout == true) {
                SharedPreferences prefs = await SharedPreferences.getInstance();
                await prefs.setBool('isLoggedIn', false);
                await prefs.remove('userData'); // Clear user data on logout
                Get.offAll(() => LoginScreen());
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildProfileAvatar({required double radius}) {
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