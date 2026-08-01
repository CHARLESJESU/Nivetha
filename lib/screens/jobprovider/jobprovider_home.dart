import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nivetha123/models/user_data.dart';
import '../auth/login.dart';
import '../../theme/branding.dart';
import 'post_job.dart';
import 'applications.dart';
import 'jobprovider_messages.dart';
import 'order_details.dart';
import '../shared/profile_edit.dart';
import '../../services/notification_service.dart';

class Jobproviderpage extends StatefulWidget {
  final UserData userData;

  const Jobproviderpage({Key? key, required this.userData}) : super(key: key);

  @override
  _JobproviderpageState createState() => _JobproviderpageState();
}

class _JobproviderpageState extends State<Jobproviderpage> {
  late UserData userData;
  int _selectedIndex = 0;
  int _backPressCounter = 0;
  DateTime? _lastBackPressed;

  @override
  void initState() {
    super.initState();
    userData = widget.userData;
    _initializePreferences();
  }

  void _initializePreferences() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', true);
    await prefs.setBool('worker', false);
    await prefs.setString('userData', jsonEncode(widget.userData.toJson()));
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
                  leading: const Icon(Icons.camera_alt, color: WNColors.blue),
                  title: const Text('Take Photo'),
                  onTap: () async {
                    final picked = await picker.pickImage(
                      source: ImageSource.camera,
                    );
                    Navigator.pop(context, picked);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library, color: WNColors.blue),
                  title: const Text('Choose from Gallery'),
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
            .doc('jobproviders')
            .collection('jobproviders')
            .doc(userData.userId)
            .update({'profileImage': base64Image});
      } catch (e) {
        if (mounted) await showWNMessage(context, isError: true, message: 'Failed to update profile image: $e');
      }
    }
  }

  Future<bool> _onWillPop() async {
    DateTime now = DateTime.now();
    if (_lastBackPressed == null ||
        now.difference(_lastBackPressed!) > const Duration(seconds: 2)) {
      _lastBackPressed = now;
      _backPressCounter = 1;
      showWNToast(context, 'Press back again to confirm exit');
      return Future.value(false);
    } else {
      _backPressCounter++;
      if (_backPressCounter >= 2) {
        final shouldExit = await _showExitSheet(context);
        if (shouldExit == true) {
          SystemNavigator.pop();
        }
      }
      return Future.value(false);
    }
  }

  Future<bool?> _showExitSheet(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _ConfirmSheet(
        icon: Icons.logout_rounded,
        title: "Exit App",
        message: "Are you sure you want to exit?",
        confirmLabel: "Exit",
      ),
    );
  }

  Future<bool?> _showLogoutSheet(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _ConfirmSheet(
        icon: Icons.logout_rounded,
        title: "Logout",
        message: "Are you sure you want to logout?",
        confirmLabel: "Logout",
      ),
    );
  }

  Widget _buildSelectedPage() {
    switch (_selectedIndex) {
      case 0:
        return OrderDetailsPage(userId: widget.userData.userId);
      case 1:
        return ApplicationsPage(jobProviderUserId: userData.userId);
      case 2:
        return MessagesPage(jobProviderId: userData.userId);
      default:
        return OrderDetailsPage(userId: widget.userData.userId);
    }
  }

  String _titleForIndex() {
    switch (_selectedIndex) {
      case 0:
        return 'Welcome, ${userData.name}';
      case 1:
        return 'Applications';
      case 2:
        return 'Messages';
      default:
        return 'Welcome, ${userData.name}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();

    return WillPopScope(
      onWillPop: _onWillPop,
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
        body: Stack(
          children: [
            _buildSelectedPage(),
            if (_selectedIndex == 0)
              Positioned(
                bottom: 16,
                right: 16,
                child: FloatingActionButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (_) => FormPage(userId: widget.userData.userId),
                      ),
                    );
                  },
                  backgroundColor: WNColors.blue,
                  elevation: 2,
                  child: const Icon(Icons.add, color: Colors.white),
                ),
              ),
          ],
        ),
        bottomNavigationBar: _buildBottomNav(),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
            _buildNavItem(icon: Icons.list_alt_rounded, label: 'Orders', index: 0),
            const SizedBox(width: 8),
            _buildNavItem(icon: Icons.assignment_ind_rounded, label: 'Applications', index: 1),
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
                      child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
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
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: WNColors.blue),
            title: const Text('Logout'),
            onTap: () async {
              final shouldLogout = await _showLogoutSheet(context);
              if (shouldLogout == true) {
                SharedPreferences prefs = await SharedPreferences.getInstance();
                await prefs.setBool('isLoggedIn', false);
                await prefs.remove('userData');
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

class _ConfirmSheet extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String confirmLabel;

  const _ConfirmSheet({
    required this.icon,
    required this.title,
    required this.message,
    required this.confirmLabel,
  });

  @override
  Widget build(BuildContext context) {
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
            child: Icon(icon, color: WNColors.blue, size: 32),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: WNColors.navy),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: Colors.black54),
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
                    child: Text(confirmLabel, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
