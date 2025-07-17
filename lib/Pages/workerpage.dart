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
  int unreadMessagesCount = 0;

  @override
  void initState() {
    super.initState();
    userData = widget.userData;
    _initializePreferences();
    _loadAppliedJobs();
    _loadPosts();
    _loadUnreadMessagesCount();
  }

  void _initializePreferences() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', true);
    await prefs.setBool('worker', true);
    await prefs.setString('userData', jsonEncode(widget.userData.toJson()));
  }

  Future<void> _loadUnreadMessagesCount() async {
    final workerId = userData.userId;
    final messagesRef = FirebaseFirestore.instance
        .collection('messages')
        .doc('worker_$workerId')
        .collection('chats');

    final snapshot = await messagesRef.get();

    int count = 0;
    for (var doc in snapshot.docs) {
      final lastMessage = doc.data()['lastMessage'] as Map<String, dynamic>?;
      if (lastMessage != null &&
          lastMessage['isRead'] == false &&
          lastMessage['senderId'] != workerId) {
        count++;
      }
    }

    setState(() {
      unreadMessagesCount = count;
    });
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

          final ordersSnapshot =
              await workerDoc.reference.collection('order').get();
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

          final providerSnapshot =
              await FirebaseFirestore.instance
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
          continue;
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

      await postRef.collection('workers').doc(workerUserId).set(workerDetails);

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

      await jobRef.collection('posts').doc(postId).set(appliedJobDetails);

      // Initialize chat between worker and job provider
      await _initializeChat(jobProviderUserId);

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

  Future<void> _initializeChat(String jobProviderId) async {
    try {
      final workerId = userData.userId;
      final workerName = userData.name;

      // Create chat in worker's messages
      await FirebaseFirestore.instance
          .collection('messages')
          .doc('worker_$workerId')
          .collection('chats')
          .doc(jobProviderId)
          .set({
            'jobProviderId': jobProviderId,
            'jobProviderName':
                jobProviderDetails[jobProviderId]?.name ?? 'Unknown',
            'lastMessage': {
              'text': 'Chat initiated',
              'timestamp': DateTime.now().toIso8601String(),
              'isRead': true,
              'senderId': workerId,
            },
          });

      // Create chat in job provider's messages
      await FirebaseFirestore.instance
          .collection('messages')
          .doc('provider_$jobProviderId')
          .collection('chats')
          .doc(workerId)
          .set({
            'workerId': workerId,
            'workerName': workerName,
            'lastMessage': {
              'text': 'Chat initiated',
              'timestamp': DateTime.now().toIso8601String(),
              'isRead': false,
              'senderId': workerId,
            },
          });
    } catch (e) {
      print("Error initializing chat: $e");
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
    } else if (_selectedIndex == 1) {
      return JobStatusPage(userData: userData);
    } else {
      return MessagesPage(
        workerId: userData.userId,
        workerName: userData.name,
        onMessageRead: _loadUnreadMessagesCount,
      );
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
                      children: [
                        Expanded(
                          child: Text(
                            "Job Provider: $providerName",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.blueAccent,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (!didPop) {
          backController.handleWillPop();
        }
      },
      child: Scaffold(
        key: scaffoldKey,
        appBar: AppBar(
          title: Text(
            _selectedIndex == 0
                ? 'Welcome, ${userData.name}'
                : _selectedIndex == 1
                ? 'Job Status'
                : 'Messages',
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
          actions:
              _selectedIndex == 2
                  ? [
                    Stack(
                      children: [
                        IconButton(
                          icon: Icon(Icons.refresh),
                          onPressed: () {
                            _loadUnreadMessagesCount();
                            if (_MessagesPageState.currentState != null) {
                              _MessagesPageState.currentState!._loadChats();
                            }
                          },
                        ),
                        if (unreadMessagesCount > 0)
                          Positioned(
                            right: 8,
                            top: 8,
                            child: Container(
                              padding: EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              constraints: BoxConstraints(
                                minWidth: 16,
                                minHeight: 16,
                              ),
                              child: Text(
                                unreadMessagesCount.toString(),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ]
                  : null,
        ),
        drawer: buildDrawer(),
        body: RefreshIndicator(
          onRefresh: _loadPosts,
          child: _buildMainContent(),
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedIndex,
          selectedItemColor: Colors.blueAccent,
          onTap: (index) => setState(() => _selectedIndex = index),
          items: [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(
              icon: Icon(Icons.assignment),
              label: 'Job Status',
            ),
            BottomNavigationBarItem(
              icon: Stack(
                children: [
                  Icon(Icons.message),
                  if (unreadMessagesCount > 0)
                    Positioned(
                      right: 0,
                      child: Container(
                        padding: EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        constraints: BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          unreadMessagesCount.toString(),
                          style: TextStyle(color: Colors.white, fontSize: 10),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              label: 'Messages',
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
                      padding: EdgeInsets.all(3),
                      child: Icon(
                        Icons.edit,
                        size: 20,
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

class MessagesPage extends StatefulWidget {
  final String workerId;
  final String workerName;
  final VoidCallback onMessageRead;

  const MessagesPage({
    required this.workerId,
    required this.workerName,
    required this.onMessageRead,
    Key? key,
  }) : super(key: key);

  @override
  _MessagesPageState createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ScrollController _scrollController = ScrollController();

  Map<String, Map<String, dynamic>> _chats = {};
  bool _isLoading = true;
  String? _selectedChatId;
  List<Map<String, dynamic>> _messages = [];
  bool _isSending = false;

  static _MessagesPageState? currentState;

  @override
  void initState() {
    super.initState();
    currentState = this;
    _loadChats();
    _setupMessageListener();
  }

  @override
  void dispose() {
    currentState = null;
    _messageController.dispose();
    _messageFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadChats() async {
    try {
      final snapshot =
          await _firestore
              .collection('messages')
              .doc('worker_${widget.workerId}')
              .collection('chats')
              .get();

      setState(() {
        _chats = {for (var doc in snapshot.docs) doc.id: doc.data()};
        _isLoading = false;
      });
    } catch (e) {
      print("Error loading chats: $e");
      setState(() => _isLoading = false);
    }
  }

  void _setupMessageListener() {
    if (_selectedChatId != null) {
      _firestore
          .collection('messages')
          .doc('worker_${widget.workerId}')
          .collection('chats')
          .doc(_selectedChatId!)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .snapshots()
          .listen((snapshot) {
            if (snapshot.docs.isNotEmpty) {
              setState(() {
                _messages = snapshot.docs.map((doc) => doc.data()).toList();
              });
              _scrollToBottom();
            }
          });
    }
  }

  Future<void> _loadMessages(String chatId) async {
    setState(() {
      _selectedChatId = chatId;
      _messages = [];
      _isLoading = true;
    });

    try {
      final snapshot =
          await _firestore
              .collection('messages')
              .doc('worker_${widget.workerId}')
              .collection('chats')
              .doc(chatId)
              .collection('messages')
              .orderBy('timestamp', descending: true)
              .limit(50)
              .get();

      // Mark messages as read
      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        final message = doc.data();
        if (message['senderId'] != widget.workerId &&
            message['isRead'] == false) {
          batch.update(doc.reference, {'isRead': true});
        }
      }
      await batch.commit();

      // Update last message read status
      if (snapshot.docs.isNotEmpty) {
        final lastMessage = snapshot.docs.first.data();
        if (lastMessage['senderId'] != widget.workerId) {
          await _firestore
              .collection('messages')
              .doc('worker_${widget.workerId}')
              .collection('chats')
              .doc(chatId)
              .update({'lastMessage.isRead': true});
        }
      }

      setState(() {
        _messages = snapshot.docs.map((doc) => doc.data()).toList();
        _isLoading = false;
      });

      widget.onMessageRead();
      _scrollToBottom();
    } catch (e) {
      print("Error loading messages: $e");
      setState(() => _isLoading = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _selectedChatId == null)
      return;

    final messageId = DateTime.now().millisecondsSinceEpoch.toString();
    final messageData = {
      'messageId': messageId,
      'text': _messageController.text.trim(),
      'senderId': widget.workerId,
      'senderName': widget.workerName,
      'timestamp': DateTime.now().toIso8601String(),
      'isRead': false,
    };

    setState(() => _isSending = true);

    try {
      // Add message to messages subcollection
      await _firestore
          .collection('messages')
          .doc('worker_${widget.workerId}')
          .collection('chats')
          .doc(_selectedChatId!)
          .collection('messages')
          .doc(messageId)
          .set(messageData);

      // Update last message in chat
      await _firestore
          .collection('messages')
          .doc('worker_${widget.workerId}')
          .collection('chats')
          .doc(_selectedChatId!)
          .update({'lastMessage': messageData});

      // Also update the job provider's chat
      await _firestore
          .collection('messages')
          .doc('provider_$_selectedChatId')
          .collection('chats')
          .doc(widget.workerId)
          .set({
            'jobProviderId': _selectedChatId,
            'workerId': widget.workerId,
            'workerName': widget.workerName,
            'lastMessage': messageData,
          }, SetOptions(merge: true));

      // Add message to job provider's messages
      await _firestore
          .collection('messages')
          .doc('provider_$_selectedChatId')
          .collection('chats')
          .doc(widget.workerId)
          .collection('messages')
          .doc(messageId)
          .set(messageData);

      _messageController.clear();
      _scrollToBottom();
    } catch (e) {
      print("Error sending message: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to send message")));
    } finally {
      setState(() => _isSending = false);
    }
  }

  void _sendQuickReply(String message) {
    _messageController.text = message;
    _sendMessage();
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? Center(child: CircularProgressIndicator())
        : _selectedChatId == null
        ? _buildChatList()
        : _buildChatScreen();
  }

  Widget _buildChatList() {
    return ListView.builder(
      itemCount: _chats.length,
      itemBuilder: (context, index) {
        final chatId = _chats.keys.elementAt(index);
        final chat = _chats[chatId]!;
        final lastMessage = chat['lastMessage'] as Map<String, dynamic>?;
        final isUnread =
            lastMessage != null &&
            lastMessage['isRead'] == false &&
            lastMessage['senderId'] != widget.workerId;

        return ListTile(
          leading: CircleAvatar(
            child: Text(chat['jobProviderName']?.substring(0, 1) ?? '?'),
          ),
          title: Text(chat['jobProviderName'] ?? 'Unknown'),
          subtitle: Text(
            lastMessage?['text'] ?? 'No messages yet',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                lastMessage != null
                    ? _formatTime(lastMessage['timestamp'])
                    : '',
                style: TextStyle(fontSize: 12),
              ),
              if (isUnread)
                Container(
                  margin: EdgeInsets.only(top: 4),
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
          onTap: () => _loadMessages(chatId),
        );
      },
    );
  }

  Widget _buildChatScreen() {
    final chat = _chats[_selectedChatId]!;
    final jobProviderName = chat['jobProviderName'] ?? 'Unknown';

    return Column(
      children: [
        AppBar(
          title: Text(jobProviderName),
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () {
              setState(() => _selectedChatId = null);
              _loadChats();
            },
          ),
        ),
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            reverse: true,
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              final message = _messages[index];
              final isMe = message['senderId'] == widget.workerId;

              return Padding(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Align(
                  alignment:
                      isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    child: Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isMe ? Colors.blue[100] : Colors.grey[300],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!isMe)
                            Text(
                              message['senderName'],
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[800],
                              ),
                            ),
                          SizedBox(height: 4),
                          Text(message['text']),
                          SizedBox(height: 4),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _formatTime(message['timestamp']),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey[600],
                                ),
                              ),
                              if (isMe)
                                Padding(
                                  padding: EdgeInsets.only(left: 4),
                                  child: Icon(
                                    message['isRead'] == true
                                        ? Icons.done_all
                                        : Icons.done,
                                    size: 12,
                                    color:
                                        message['isRead'] == true
                                            ? Colors.blue
                                            : Colors.grey,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        _buildMessageInput(),
      ],
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[300]!, width: 1)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TextButton(
                onPressed: () => _sendQuickReply('Yes, I am Interested'),
                child: Text('Yes, I am Interested'),
              ),
              TextButton(
                onPressed: () => _sendQuickReply('No, I am Not Interested'),
                child: Text('No, I am Not Interested'),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  focusNode: _messageFocusNode,
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey[200],
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  maxLines: null,
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              SizedBox(width: 8),
              CircleAvatar(
                backgroundColor: Colors.blue,
                child: IconButton(
                  icon:
                      _isSending
                          ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                          : Icon(Icons.send, color: Colors.white),
                  onPressed: _sendMessage,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTime(String timestamp) {
    try {
      final dateTime = DateTime.parse(timestamp).toLocal();
      return '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return '';
    }
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
