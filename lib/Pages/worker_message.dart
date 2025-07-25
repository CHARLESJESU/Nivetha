import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ConfirmationMessagesPage extends StatelessWidget {
  final String workerId;

  const ConfirmationMessagesPage({Key? key, required this.workerId})
    : super(key: key);

  Future<void> sendResponseMessage({
    required String jobProviderId,
    required String postId,
    required String response,
    required String senderWorkerId,
  }) async {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    final Timestamp now = Timestamp.now();

    // Send reply to job provider
    await firestore
        .collection('messages')
        .doc('jobprovider_$jobProviderId')
        .collection('chats')
        .add({
          'text': response,
          'senderId': senderWorkerId,
          'receiverId': jobProviderId,
          'senderType': 'worker',
          'receiverType': 'job_provider',
          'timestamp': now,
          'postId': postId,
          'isRead': false,
        });

    // Optionally store the response on the worker side too
    await firestore
        .collection('messages')
        .doc('worker_$senderWorkerId')
        .collection('chats')
        .add({
          'text': "You replied: $response",
          'senderId': senderWorkerId,
          'receiverId': jobProviderId,
          'senderType': 'worker',
          'receiverType': 'job_provider',
          'timestamp': now,
          'postId': postId,
          'isRead': true,
        });
  }

  @override
  Widget build(BuildContext context) {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Confirmation Messages'),
        backgroundColor: Colors.orange,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream:
            firestore
                .collection('messages')
                .doc('worker_$workerId')
                .collection('chats')
                .orderBy('timestamp', descending: true)
                .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final messages = snapshot.data!.docs;

          if (messages.isEmpty) {
            return const Center(child: Text('No messages found'));
          }

          return ListView.builder(
            itemCount: messages.length,
            itemBuilder: (context, index) {
              final msg = messages[index].data() as Map<String, dynamic>;
              final text = msg['text'] ?? '';
              final senderId = msg['senderId'] ?? '';
              final postId = msg['orderId'] ?? 'N/A';

              final Timestamp? timestamp = msg['timestamp'];
              final timeStr =
                  timestamp != null
                      ? timestamp.toDate().toLocal().toString().split('.')[0]
                      : 'Unknown';

              return Card(
                margin: const EdgeInsets.all(10),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Post ID: $postId",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text("Message: $text"),
                      const SizedBox(height: 8),
                      Text("From: $senderId"),
                      Text(
                        "At: $timeStr",
                        style: const TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton.icon(
                            onPressed:
                                () => sendResponseMessage(
                                  jobProviderId: senderId,
                                  postId: postId,
                                  response: "Yes, I am interested",
                                  senderWorkerId: workerId,
                                ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                            ),
                            icon: const Icon(
                              Icons.thumb_up,
                              color: Colors.white,
                            ),
                            label: const Text(
                              "I'm Interested",
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed:
                                () => sendResponseMessage(
                                  jobProviderId: senderId,
                                  postId: postId,
                                  response: "No, I'm not interested",
                                  senderWorkerId: workerId,
                                ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                            ),
                            icon: const Icon(
                              Icons.thumb_down,
                              color: Colors.white,
                            ),
                            label: const Text(
                              "Not Interested",
                              style: TextStyle(color: Colors.white),
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
        },
      ),
    );
  }
}
