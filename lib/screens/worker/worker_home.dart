import 'dart:convert';

import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:flutter/material.dart';

import 'package:geocoding/geocoding.dart';

import 'package:get/get.dart';

import 'package:image_picker/image_picker.dart';

import 'package:firebase_database/firebase_database.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:nivetha123/screens/worker/worker_content_view.dart';

import 'package:nivetha123/models/job_provider.dart';

import 'package:nivetha123/models/post.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../auth/login.dart';

import '../../models/user_data.dart';

import '../../services/back_button_controller.dart';

import 'job_status_page.dart';

import '../shared/map_page.dart';

import '../shared/profile_edit.dart';
import 'worker_messages.dart';
import '../../theme/branding.dart';
import '../../services/notification_service.dart';


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
  Map<String, bool> applyingJobs = {};
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
      if (mounted) showWNMessage(context, isError: true, message: "Failed to load jobs: $e");
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
      final base64Image = await compressImageToBase64(image.path);
      if (base64Image == null) {
        if (mounted) await showWNMessage(context, isError: true, message: 'Failed to process image.');
        return;
      }

      setState(() {
        userData.profileImage = base64Image;
      });
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('userData', jsonEncode(userData.toJson()));
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc('workers')
            .collection('workers')
            .doc(userData.userId)
            .update({'profileImage': base64Image});
      } catch (e) {
        if (mounted) await showWNMessage(context, isError: true, message: 'Failed to update profile image: $e');
      }
    }
  }

  Future<void> _applyForJob(String jobProviderUserId, String postId) async {
    if (applyingJobs[postId] == true) return; // already in flight, ignore double-tap

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      showWNMessage(context, isError: true, message: "Please log in to apply for jobs");
      return;
    }

    setState(() => applyingJobs[postId] = true);

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
        showWNMessage(context, isError: true, message: "Post not found or invalid");
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

      if (mounted) await _showAppliedSuccessDialog();
    } catch (e) {
      if (mounted) showWNMessage(context, isError: true, message: "Failed to apply to the job: $e");
    } finally {
      if (mounted) setState(() => applyingJobs[postId] = false);
    }
  }

  Future<void> _showAppliedSuccessDialog() {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: WNColors.blue.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle, color: WNColors.blue, size: 44),
                ),
                const SizedBox(height: 20),
                const Text(
                  "Application Sent!",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: WNColors.navy),
                ),
                const SizedBox(height: 8),
                const Text(
                  "You've successfully applied to this job. The job provider will review it soon.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.black54),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: WNColors.blue,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text("Done", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMainContent() {
    if (_selectedIndex == 0) {
      return WorkerContentView(
        posts: posts,
        isLoading: isLoading,
        appliedJobs: appliedJobs,
        applyingJobs: applyingJobs,
        jobProviderDetails: jobProviderDetails,
        selectedCity: selectedCity,
        availableCities: availableCities,
        onCityChanged: (city) => setState(() => selectedCity = city),
        onApplyForJob: _applyForJob,
        onRefreshPosts: _loadPosts, // Pass the refresh function down
      );
    } else if (_selectedIndex == 1) {
      return JobStatusPage(userData: userData);
    } else {
      return WorkerMessagesPage(workerId: userData.userId);
    }
  }

  String _titleForIndex() {
    switch (_selectedIndex) {
      case 0:
        return 'Welcome, ${userData.name}';
      case 1:
        return 'Job Status';
      case 2:
        return 'Messages';
      default:
        return 'Welcome, ${userData.name}';
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
        backgroundColor: WNColors.bg,
        appBar: AppBar(
          title: Text(
            _titleForIndex(),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: 20,
            ),
          ),
          backgroundColor: WNColors.blue,
          elevation: 0,
          leading: IconButton(
            icon: _buildProfileAvatar(radius: 20),
            onPressed: () => scaffoldKey.currentState?.openDrawer(),
          ),
        ),
        drawer: buildDrawer(),
        body: _buildMainContent(),
        bottomNavigationBar: _buildBottomNav(),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            _buildNavItem(icon: Icons.home_rounded, label: 'Home', index: 0),
            const SizedBox(width: 8),
            _buildNavItem(icon: Icons.assignment_rounded, label: 'Job Status', index: 1),
            const SizedBox(width: 8),
            _buildNavItem(
              icon: Icons.message_rounded,
              label: 'Messages',
              index: 2,
              badge: NotificationService.chatUnreadCount,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
    ValueNotifier<int>? badge,
  }) {
    final bool selected = _selectedIndex == index;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          setState(() => _selectedIndex = index);
          badge?.value = 0;
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? WNColors.blue.withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(icon, color: selected ? WNColors.blue : Colors.black45, size: 24),
                  if (badge != null)
                    Positioned(
                      right: -6,
                      top: -4,
                      child: ValueListenableBuilder<int>(
                        valueListenable: badge,
                        builder: (context, count, _) {
                          if (count <= 0) return const SizedBox.shrink();
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            constraints: const BoxConstraints(minWidth: 16),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              count > 9 ? '9+' : '$count',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected ? WNColors.blue : Colors.black45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool?> _showLogoutSheet(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: WNColors.blue.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.logout_rounded, color: WNColors.blue, size: 32),
              ),
              const SizedBox(height: 16),
              const Text(
                "Logout",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: WNColors.navy),
              ),
              const SizedBox(height: 8),
              const Text(
                "Are you sure you want to logout?",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.black54),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: WNColors.blue),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text("Cancel", style: TextStyle(color: WNColors.blue, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: WNColors.blue,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text("Logout", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
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
                      decoration: BoxDecoration(
                        color: WNColors.blue,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      padding: const EdgeInsets.all(6),
                      child: const Icon(
                        Icons.camera_alt,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            decoration: const BoxDecoration(color: WNColors.blue),
          ),
          ListTile(
            leading: const Icon(Icons.person, color: WNColors.blue),
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
            leading: const Icon(Icons.logout, color: WNColors.blue),
            title: const Text('Logout'),
            onTap: () async {
              final shouldLogout = await _showLogoutSheet(context);
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
    return WNAvatar(imageBase64: userData.profileImage, name: userData.name, radius: radius);
  }
}