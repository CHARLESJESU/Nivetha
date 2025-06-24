// import the new speech_to_text package
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt; // 🔹 NEW
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

  List<Post> posts = [];
  bool isLoading = true;
  Map<String, bool> appliedJobs = {};
  Map<String, JobProvider> jobProviderDetails = {};

  // 🔹 NEW: Speech + City Filter
  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _selectedCity = 'All';

  @override
  void initState() {
    super.initState();
    userData = widget.userData;
    _speech = stt.SpeechToText(); // 🔹 NEW
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
          final providerSnapshot =
              await FirebaseDatabase.instance
                  .ref()
                  .child('users/jobproviders/$userId')
                  .get();

          if (providerSnapshot.exists) {
            final v = providerSnapshot.value as Map<dynamic, dynamic>;
            fetchedJobProviders[userId] = JobProvider(
              name: v['name'] ?? '',
              gender: v['gender'] ?? '',
              dob: v['dob'] ?? '',
              email: v['email-id'] ?? '',
              phone: v['phone'] ?? '',
              address: v['address'] ?? '',
              area: v['area'] ?? '',
              city: v['city'] ?? '',
              district: v['district'] ?? '',
              state: v['state'] ?? '',
              country: v['country'] ?? '',
              experience: v['experience'] ?? '',
              role: v['role'] ?? '',
              profileImageBase64: v['profileImageBase64'] ?? '',
            );
          }
        }
      }

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

      if (post.postId.isEmpty) {
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

  // 🔹 NEW: Voice listening method
  void _listenCityVoice() async {
    if (!_isListening) {
      bool available = await _speech.initialize();
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (res) {
            setState(() {
              _selectedCity = res.recognizedWords;
            });
          },
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  Widget _buildMainContent() {
    return _selectedIndex == 0
        ? buildJobPosts()
        : JobStatusPage(userData: userData);
  }

  Widget buildJobPosts() {
    if (isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    final filteredPosts =
        _selectedCity == 'All'
            ? posts
            : posts
                .where(
                  (p) => jobProviderDetails[p.userId]?.city == _selectedCity,
                )
                .toList();

    return Column(
      children: [
        // 🔹 NEW: Filter UI
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedCity,
                  items:
                      [
                            'All',
                            ...posts
                                .map(
                                  (p) =>
                                      jobProviderDetails[p.userId]?.city ?? '',
                                )
                                .where((c) => c.isNotEmpty)
                                .toSet(),
                          ]
                          .map(
                            (city) => DropdownMenuItem(
                              value: city,
                              child: Text(city),
                            ),
                          )
                          .toList(),
                  onChanged: (val) {
                    setState(() => _selectedCity = val!);
                  },
                  decoration: InputDecoration(
                    labelText: 'Filter by City',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12),
                  ),
                ),
              ),
              SizedBox(width: 8),
              IconButton(
                icon: Icon(
                  _isListening ? Icons.mic : Icons.mic_none,
                  color: Colors.blue,
                ),
                onPressed: _listenCityVoice,
              ),
            ],
          ),
        ),
        Expanded(
          child:
              filteredPosts.isEmpty
                  ? Center(child: Text("No jobs available."))
                  : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: filteredPosts.length,
                    itemBuilder: (context, idx) {
                      final post = filteredPosts[idx];
                      final isApplied = appliedJobs[post.postId] ?? false;
                      final provider = jobProviderDetails[post.userId]!;
                      final providerAddress = provider.address;

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
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
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
                                      if (providerAddress.isNotEmpty) {
                                        try {
                                          List<Location> locs =
                                              await locationFromAddress(
                                                providerAddress,
                                              );
                                          if (locs.isNotEmpty) {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder:
                                                    (_) => MapPage(
                                                      latitude:
                                                          locs[0].latitude,
                                                      longitude:
                                                          locs[0].longitude,
                                                      address: providerAddress,
                                                    ),
                                              ),
                                            );
                                          }
                                        } catch (e) {
                                          print("Error finding location: $e");
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                "Couldn't find location",
                                              ),
                                            ),
                                          );
                                        }
                                      } else {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text("Address is empty"),
                                          ),
                                        );
                                      }
                                    },
                                  ),
                                ],
                              ),
                              Text(
                                "City: ${provider.city}",
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
                                                    backgroundColor:
                                                        Colors.black,
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
          ...[
            ['User Id', userData.userId],
            ['Role', userData.role],
            ['Gender', userData.gender],
            [
              'DOB',
              userData.dob?.toLocal().toString().split(' ')[0] ?? 'Not Set',
            ],
            ['Phone', userData.phoneNumber],
            ['Country', userData.country],
            ['State', userData.state],
            ['District', userData.district],
            ['City', userData.city],
            ['Area', userData.area],
            ['Address', userData.address],
            if (userData.role == 'Worker')
              ['Experience', userData.experience ?? ''],
          ].map(
            (e) => Padding(
              padding: const EdgeInsets.symmetric(
                vertical: 4.0,
                horizontal: 16.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${e[0]}:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  Text(e[1]!, style: TextStyle(fontSize: 16)),
                ],
              ),
            ),
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
  final String name,
      gender,
      dob,
      email,
      phone,
      address,
      area,
      city,
      district,
      state,
      country,
      experience,
      role,
      profileImageBase64;

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
