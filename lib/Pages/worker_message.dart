import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ConfirmationMessagesPage extends StatefulWidget {
  final String workerId;
  final String workerName;

  const ConfirmationMessagesPage({
    Key? key,
    required this.workerId,
    required this.workerName,
  }) : super(key: key);

  @override
  _ConfirmationMessagesPageState createState() =>
      _ConfirmationMessagesPageState();
}

class _ConfirmationMessagesPageState extends State<ConfirmationMessagesPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Welcome, Swetha"),
        backgroundColor: Colors.blue,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream:
            _firestore
                .collection('messages')
                .doc('worker_${widget.workerId}')
                .collection('chats')
                .where('senderType', isEqualTo: 'job_provider')
                .where('responded', isEqualTo: false)
                .orderBy('timestamp', descending: true)
                .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final messages = snapshot.data?.docs ?? [];

          if (messages.isEmpty) {
            return const Center(
              child: Opacity(
                opacity: 0.2,
                child: Text("No Msg", style: TextStyle(fontSize: 24)),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: messages.length,
            itemBuilder: (context, index) {
              final msgDoc = messages[index];
              final msg = msgDoc.data() as Map<String, dynamic>;

              return Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Post ID: ${msg['postId'] ?? 'N/A'}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(msg['text'] ?? 'No message'),
                      const SizedBox(height: 8),
                      Text(
                        'From Job Provider ID: ${msg['senderId']}',
                        style: const TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          ElevatedButton(
                            onPressed: () {
                              _sendResponse(
                                jobProviderId: msg['senderId'],
                                postId: msg['postId'],
                                isInterested: true,
                                originalDoc: msgDoc.reference,
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            child: const Text("I’m Interested"),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton(
                            onPressed: () {
                              _sendResponse(
                                jobProviderId: msg['senderId'],
                                postId: msg['postId'],
                                isInterested: false,
                                originalDoc: msgDoc.reference,
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            child: const Text("I’m Not Interested"),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _sendResponse({
    required String jobProviderId,
    required String postId,
    required bool isInterested,
    required DocumentReference originalDoc,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final responseText =
        isInterested ? "Yes, I'm interested" : "No, I'm not interested";

    final messageData = {
      'text': responseText,
      'senderId': widget.workerId,
      'senderName': widget.workerName,
      'senderType': 'worker',
      'receiverType': 'job_provider',
      'timestamp': Timestamp.now(),
      'isRead': false,
      'postId': postId,
    };

    try {
      // Add message to job provider's inbox
      await _firestore
          .collection('messages')
          .doc('jobprovider_$jobProviderId')
          .collection('chats')
          .add(messageData);

      // Mark original message as responded
      await originalDoc.update({'responded': true});

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Response sent to job provider.')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to send response: $e')));
    }
  }
}
