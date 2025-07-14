import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
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
    _loadPosts();
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

          // Fetch job provider details
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
  Future<void> _refreshData() async {
    // 👇 Add your refresh logic here
    // For example, re-fetch user data or posts
    await _loadAppliedJobs(); // if you have a method like this
    setState(() {});
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

// ✅ Set a dummy or useful field to ensure `postId` exists
      await postRef.set({'active': true}, SetOptions(merge: true));

// ✅ Then save the worker under 'workers' collection
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

// ✅ Ensure the jobProvider document exists with at least one field
      await jobRef.set({'summa': 1}, SetOptions(merge: true)); // Or use any meaningful field

// ✅ Now save the post inside 'posts' subcollection
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
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: DropdownButton<String?>(
              value: selectedCity,
              hint: Text("Filter by City"),
              isExpanded: true,
              items: [
                DropdownMenuItem<String?>(
                  value: null,
                  child: Text("All Cities"),
                ),
                ...availableCities.map(
                  (city) =>
                      DropdownMenuItem<String?>(value: city, child: Text(city)),
                ),
              ],
              onChanged: (value) {
                setState(() => selectedCity = value);
              },
            ),
          ),
          Expanded(child: buildJobPosts()),
        ],
      );
    } else {
      return JobStatusPage(userData: userData);
    }
  }

  Widget buildJobPosts() {
    final filteredPosts =
        selectedCity == null
            ? posts
            : posts.where((post) {
              final provider = jobProviderDetails[post.userId];
              return provider?.city == selectedCity;
            }).toList();

    return isLoading
        ? Center(child: CircularProgressIndicator())
        : filteredPosts.isEmpty
        ? Center(child: Text("No jobs available for selected city."))
        : ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: filteredPosts.length,
          itemBuilder: (context, index) {
            final post = filteredPosts[index];
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
                            if (providerAddress.isNotEmpty) {
                              try {
                                List<Location> locations =
                                    await locationFromAddress(providerAddress);
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
                                            address: providerAddress,
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
                        ),
                      ],
                    ),
                    SizedBox(height: 2),
                    Text(
                      "City: ${provider?.city ?? ''}",
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
        body: RefreshIndicator(
          onRefresh: _refreshData,
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
              style: TextStyle(fontWeight: FontWeight.bold),
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
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            decoration: BoxDecoration(color: Colors.blueAccent),
          ),
          ListTile(
            leading: Icon(Icons.person),
            title: Text('Profile Details'),
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

class ProfilePage extends StatefulWidget {
  final UserData userData;
  const ProfilePage({Key? key, required this.userData}) : super(key: key);

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late UserData userData;
  bool isEditing = false;
  Map<String, TextEditingController> controllers = {};

  @override
  void initState() {
    super.initState();
    userData = widget.userData;
    controllers = {
      'name': TextEditingController(text: userData.name),
      'role': TextEditingController(text: userData.role),
      'gender': TextEditingController(text: userData.gender),
      'dob': TextEditingController(
        text: userData.dob?.toLocal().toString().split(' ')[0] ?? '',
      ),
      'phone': TextEditingController(text: userData.phoneNumber),
      'country': TextEditingController(text: userData.country),
      'state': TextEditingController(text: userData.state),
      'district': TextEditingController(text: userData.district),
      'city': TextEditingController(text: userData.city),
      'area': TextEditingController(text: userData.area),
      'address': TextEditingController(text: userData.address),
      'experience': TextEditingController(text: userData.experience ?? ''),
    };
  }

  @override
  void dispose() {
    controllers.values.forEach((controller) => controller.dispose());
    super.dispose();
  }

  void _saveChanges() async {
    setState(() {
      userData = UserData(
        userId: userData.userId,
        name: controllers['name']!.text,
        role: controllers['role']!.text,
        gender: controllers['gender']!.text,
        dob: DateTime.tryParse(controllers['dob']!.text),
        phoneNumber: controllers['phone']!.text,
        country: controllers['country']!.text,
        state: controllers['state']!.text,
        district: controllers['district']!.text,
        city: controllers['city']!.text,
        area: controllers['area']!.text,
        address: controllers['address']!.text,
        profileImage: userData.profileImage,
        experience: controllers['experience']!.text,
      );
      isEditing = false;
    });

    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('userData', jsonEncode(userData.toJson()));

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc('workers')
          .collection('workers')
          .doc(userData.userId)
          .update(userData.toJson());

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Profile updated successfully')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to update profile: $e')));
    }
  }

  Widget _buildProfileDetail(
    String label,
    String value, {
    bool isEditable = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              '$label:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            flex: 3,
            child:
                isEditing && isEditable
                    ? TextField(
                      controller: controllers[label.toLowerCase()],
                      decoration: InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 8),
                      ),
                    )
                    : Text(value, style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Profile Details'),
        backgroundColor: Colors.blueAccent,
        actions: [
          if (!isEditing)
            IconButton(
              icon: Icon(Icons.edit),
              onPressed: () => setState(() => isEditing = true),
            ),
          if (isEditing)
            IconButton(icon: Icon(Icons.save), onPressed: _saveChanges),
          if (isEditing)
            IconButton(
              icon: Icon(Icons.cancel),
              onPressed: () => setState(() => isEditing = false),
            ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.all(16.0),
        children: [
          Center(
            child: Stack(
              children: [
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
                        size: 24,
                        color: Colors.blueAccent,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 20),
          _buildProfileDetail('Name', userData.name, isEditable: true),
          _buildProfileDetail('Role', userData.role, isEditable: true),
          _buildProfileDetail('Gender', userData.gender, isEditable: true),
          _buildProfileDetail(
            'DOB',
            userData.dob?.toLocal().toString().split(' ')[0] ?? 'Not Set',
            isEditable: true,
          ),
          _buildProfileDetail('Phone', userData.phoneNumber, isEditable: true),
          _buildProfileDetail('Country', userData.country, isEditable: true),
          _buildProfileDetail('State', userData.state, isEditable: true),
          _buildProfileDetail('District', userData.district, isEditable: true),
          _buildProfileDetail('City', userData.city, isEditable: true),
          _buildProfileDetail('Area', userData.area, isEditable: true),
          _buildProfileDetail('Address', userData.address, isEditable: true),
          if (userData.role == 'Worker')
            _buildProfileDetail(
              'Experience',
              userData.experience ?? '',
              isEditable: true,
            ),
        ],
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
