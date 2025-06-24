// import statements remain unchanged
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../login/Login.dart';
import '../screens/user_data.dart';
import 'Backcontroll.dart';
import 'job_status_page.dart';
import 'map_pages.dart';

class Workerpage extends StatefulWidget {
  final UserData userData;
  const Workerpage({Key? key, required this.userData}) : super(key: key);

  @override
  _WorkerpageState createState() => _WorkerpageState();
}

class _WorkerpageState extends State<Workerpage> {
  late UserData userData;
  int _selectedIndex = 0;
  int _backPressCounter = 0;
  DateTime? _lastBackPressed;

  List<Post> posts = [];
  bool isLoading = true;
  Map<String, bool> appliedJobs = {};
  Map<String, JobProvider> jobProviderDetails = {};

  @override
  void initState() {
    super.initState();
    userData = widget.userData;
    _initializePreferences();
    _loadAppliedJobs(); // ✅ Load previously applied jobs
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
      Map<String, JobProvider> fetchedJobProviders = {};

      if (snapshot.exists) {
        final workersData = snapshot.value as Map<dynamic, dynamic>;

        for (final userId in workersData.keys) {
          final postsData = workersData[userId];
          if (postsData is Map<dynamic, dynamic>) {
            postsData.forEach((key, value) {
              if (value is Map<dynamic, dynamic>) {
                fetchedPosts.add(
                  Post(
                    userId: userId,
                    postId: key,
                    description: value['description'] ?? '',
                    imageBase64: value['imageBase64'] ?? '',
                    orderId: value['orderId'] ?? '',
                  ),
                );
              }
            });
          }

          // Fetch job provider details for this userId
          final providerSnapshot =
              await FirebaseDatabase.instance
                  .ref()
                  .child('users/jobproviders/$userId')
                  .get();

          if (providerSnapshot.exists) {
            final value = providerSnapshot.value as Map<dynamic, dynamic>;
            fetchedJobProviders[userId] = JobProvider(
              name: value['name'] ?? '',
              gender: value['gender'] ?? '',
              dob: value['dob'] ?? '',
              email: value['email-id'] ?? '',
              phone: value['phone'] ?? '',
              address: value['address'] ?? '',
              area: value['area'] ?? '',
              city: value['city'] ?? '',
              district: value['district'] ?? '',
              state: value['state'] ?? '',
              country: value['country'] ?? '',
              experience: value['experience'] ?? '',
              role: value['role'] ?? '',
              profileImageBase64: value['profileImageBase64'] ?? '',
            );
          }
        }
      }

      // Sort posts by postId descending
      fetchedPosts.sort((a, b) => b.postId.compareTo(a.postId));

      setState(() {
        posts = fetchedPosts;
        jobProviderDetails = fetchedJobProviders;
        isLoading = false;
      });
    } catch (e) {
      print("Failed to load posts or providers: $e");
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

      await FirebaseDatabase.instance
          .ref('applications/$jobProviderUserId/$postId/$workerUserId')
          .set(workerDetails);

      final appliedJobDetails = {
        'orderId': post.orderId,
        'description': post.description,
        'imageBase64': post.imageBase64,
        'status': 'applied',
        'appliedAt': DateTime.now().toIso8601String(),
      };

      await FirebaseDatabase.instance
          .ref('appliedJobs/$workerUserId/$jobProviderUserId/$postId')
          .set(appliedJobDetails);

      setState(() => appliedJobs[postId] = true);
      await _saveAppliedJob(postId); // ✅ Save applied job locally

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
      return buildJobPosts();
    } else {
      return JobStatusPage(userData: userData);
    }
  }

  Widget buildJobPosts() {
    return isLoading
        ? Center(child: CircularProgressIndicator())
        : posts.isEmpty
        ? Center(child: Text("No jobs available."))
        : ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final post = posts[index];
            final isApplied = appliedJobs[post.postId] ?? false;
            final provider = jobProviderDetails[post.userId];
            final providerName = provider?.name ?? "Unknown";
            final providerAddress = provider?.address ?? "";

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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Job Provider Id: ${post.userId}",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blueAccent,
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.location_on,
                            color: Colors.redAccent,
                          ),
                          onPressed: () async {
                            if (providerAddress != null &&
                                providerAddress!.isNotEmpty) {
                              try {
                                List<Location> locations =
                                    await locationFromAddress(providerAddress!);

                                if (locations.isNotEmpty) {
                                  final lat = locations[0].latitude;
                                  final lng = locations[0].longitude;

                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (context) => MapPage(
                                            latitude: lat,
                                            longitude: lng,
                                            address: providerAddress!,
                                          ),
                                    ),
                                  );
                                }
                              } catch (e) {
                                print("Error getting location: $e");
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      "Couldn't find location for the given address",
                                    ),
                                  ),
                                );
                              }
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text("Address is empty")),
                              );
                            }
                          },
                          // No functionality as requested
                        ),
                      ],
                    ),
                    SizedBox(height: 2),
                    Text(
                      "City: ${jobProviderDetails[post.userId]?.city} ",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueAccent,
                      ),
                    ),
                    SizedBox(height: 8),
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
                                              base64Decode(post.imageBase64),
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
                            crossAxisAlignment: CrossAxisAlignment.start,
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
                                  icon: Icon(Icons.work, color: Colors.white),
                                  label: Text(
                                    isApplied ? "Applied" : "Apply Now",
                                    style: TextStyle(color: Colors.white),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        isApplied ? Colors.grey : Colors.blue,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
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
            style: TextStyle(
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
        body: _buildMainContent(),
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
              final shouldLogout = await Get.dialog(
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
                SharedPreferences prefs = await SharedPreferences.getInstance();
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
  final String orderId;

  Post({
    required this.userId,
    required this.postId,
    required this.description,
    required this.imageBase64,
    required this.orderId,
  });
}

class JobProvider {
  final String name;
  final String gender;
  final String dob;
  final String email;
  final String phone;
  final String address;
  final String area;
  final String city;
  final String district;
  final String state;
  final String country;
  final String experience;
  final String role;
  final String profileImageBase64;

  JobProvider({
    required this.name,
    required this.gender,
    required this.dob,
    required this.email,
    required this.phone,
    required this.address,
    required this.area,
    required this.city,
    required this.district,
    required this.state,
    required this.country,
    required this.experience,
    required this.role,
    required this.profileImageBase64,
  });
}
