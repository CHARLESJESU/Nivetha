import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

// ponytail: no local-notifications package added — non-chat foreground
// messages show via a snackbar on whatever screen is active. Add
// flutter_local_notifications if a system-tray banner is needed while open.
class NotificationService {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  // Unread chat count shown as a badge on the Messages nav icon. In-memory
  // only — resets on app restart and when the user opens the Messages tab.
  static final ValueNotifier<int> chatUnreadCount = ValueNotifier<int>(0);

  static String userTypeFor(String userId) =>
      userId.startsWith('JO') ? 'jobproviders' : 'workers';

  // userId is the app's own generated id (e.g. WO1025 / JO1024), not the
  // Firebase Auth uid — that's how users/chat docs are keyed in this app.
  static Future<void> init({required String userId}) async {
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission();

    await _saveToken(userId);
    messaging.onTokenRefresh.listen((_) => _saveToken(userId));

    if (userTypeFor(userId) == 'workers') {
      await messaging.subscribeToTopic('workers');
    }

    FirebaseMessaging.onMessage.listen((message) {
      if (message.data['type'] == 'chat') {
        chatUnreadCount.value++;
        return;
      }

      final title = message.notification?.title;
      final body = message.notification?.body;
      if (title == null && body == null) return;
      final context = navigatorKey.currentState?.overlay?.context;
      if (context == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$title: $body')),
      );
    });
  }

  static Future<void> _saveToken(String userId) async {
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null) return;
    final userType = userTypeFor(userId);
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userType)
        .collection(userType)
        .doc(userId)
        .set({'fcmToken': token}, SetOptions(merge: true));
  }
}
