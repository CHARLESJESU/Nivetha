// import statements
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
  List<Post> posts = [];
  bool isLoading = true;
  Map<String, bool> appliedJobs = {};
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
        final workersData = snapshot.value as Map<dynamic, dynamic>;
        workersData.forEach((userId, postsData) {
          if (postsData is Map<dynamic, dynamic>) {
            postsData.forEach((key, value) {
              if (value is Map<dynamic, dynamic>) {
                final district = value['district'] ?? 'Unknown';
                districtSet.add(district);
                fetchedPosts.add(
                  Post(
                    userId: userId,
                    postId: key,
                    description: value['description'] ?? '',
                    imageBase64: value['imageBase64'] ?? '',
                    orderId: value['orderId'] ?? '',
                    district: district,
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
        availableDistricts = ['All', ...districtSet.toList()..sort()];
      });
    } catch (e) {
      print("Failed to load posts: $e");
      setState(() => isLoading = false);
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
      final post = posts.firstWhere(
        (p) => p.postId == postId && p.userId == jobProviderUserId,
        orElse:
            () => Post(
              userId: '',
              postId: '',
              orderId: '',
              description: '',
              imageBase64: '',
              district: '',
            ),
      );
      if (post.postId.isEmpty || post.userId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Post not found or invalid")),
        );
        return;
      }

      final workerDetails = {
        'workerUserId': userData.userId,
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

      final appliedJobDetails = {
        'orderId': post.orderId,
        'description': post.description,
        'imageBase64': post.imageBase64,
        'status': 'applied',
        'appliedAt': DateTime.now().toIso8601String(),
      };

      await FirebaseDatabase.instance
          .ref('applications/$jobProviderUserId/$postId/${userData.userId}')
          .set(workerDetails);
      await FirebaseDatabase.instance
          .ref('appliedJobs/${userData.userId}/$jobProviderUserId/$postId')
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

  Widget buildJobPosts() {
    final filteredPosts =
        (selectedDistrict == 'All')
            ? posts
            : posts.where((p) => p.district == selectedDistrict).toList();

    return isLoading
        ? Center(child: CircularProgressIndicator())
        : Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: DropdownButton<String>(
                value: selectedDistrict,
                isExpanded: true,
                items:
                    availableDistricts
                        .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                        .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => selectedDistrict = value);
                },
              ),
            ),
            Expanded(
              child:
                  filteredPosts.isEmpty
                      ? Center(child: Text("No jobs available."))
                      : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: filteredPosts.length,
                        itemBuilder: (context, index) {
                          final post = filteredPosts[index];
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
                                    "Job Provider Id: ${post.userId}",
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blueAccent,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    "District: ${post.district}",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                                        backgroundColor:
                                                            Colors.black,
                                                      ),
                                                      backgroundColor:
                                                          Colors.black,
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
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
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
                                                  isApplied
                                                      ? "Applied"
                                                      : "Apply Now",
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
                                                        BorderRadius.circular(
                                                          10,
                                                        ),
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
          ],
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Worker Page')),
      body: buildJobPosts(),
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
}
