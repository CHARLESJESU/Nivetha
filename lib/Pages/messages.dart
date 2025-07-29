import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MessagesPage extends StatefulWidget {
  final String jobProviderId; // Pass job provider ID here

  const MessagesPage({super.key, required this.jobProviderId});

  @override
  _MessagesPageState createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  List<Map<String, dynamic>> messages = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchMessages();
  }

  Future<void> fetchMessages() async {
    setState(() => isLoading = true);

    try {
      final snapshot =
          await FirebaseFirestore.instance
              .collection('messages')
              .doc(
                widget.jobProviderId,
              ) // 🔥 Only fetch from this provider's inbox
              .collection('inbox')
              .orderBy('timestamp', descending: true)
              .get();

      final List<Map<String, dynamic>> fetchedMessages = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (data['type'] == 'worker_response') {
          fetchedMessages.add({
            'workerId': data['from'] ?? 'Unknown',
            'postId': data['postId'] ?? 'Unknown',
            'message': data['message'] ?? 'No message',
            'timestamp': data['timestamp'],
          });
        }
      }

      setState(() {
        messages = fetchedMessages;
        isLoading = false;
      });
    } catch (e) {
      print('Error fetching messages: $e');
      setState(() => isLoading = false);
    }
  }

  Future<void> _refresh() async {
    await fetchMessages();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : messages.isEmpty
              ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.4),
                  const Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.mail_outline,
                          size: 48,
                          color: Colors.black54,
                        ),
                        SizedBox(height: 8),
                        Text('No messages yet', style: TextStyle(fontSize: 14)),
                      ],
                    ),
                  ),
                ],
              )
              : ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final msg = messages[index];
                  return ListTile(
                    leading: const Icon(Icons.message, color: Colors.blue),
                    title: Text(msg['message']),
                    subtitle: Text(
                      'Worker ID: ${msg['workerId']} • Post ID: ${msg['postId']}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing:
                        msg['timestamp'] != null
                            ? Text(
                              _formatTimestamp(msg['timestamp']),
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 11,
                              ),
                            )
                            : null,
                  );
                },
              ),
    );
  }

  String _formatTimestamp(Timestamp timestamp) {
    final dateTime = timestamp.toDate();
    return '${dateTime.year}/${dateTime.month}/${dateTime.day} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
