import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MessagesPage extends StatefulWidget {
  final String jobProviderId;

  const MessagesPage({super.key, required this.jobProviderId});

  @override
  _MessagesPageState createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  List<Map<String, dynamic>> messages = [];
  bool isLoading = true;
  final Map<String, TextEditingController> _chatControllers = {};

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
              .doc(widget.jobProviderId)
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
            'response': data['response'] ?? 'unknown',
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

  Future<void> _sendMessageToWorker({
    required String workerId,
    required String postId,
    required String text,
  }) async {
    final ref = FirebaseFirestore.instance
        .collection('messages')
        .doc(workerId)
        .collection('inbox');

    try {
      await ref.add({
        'from': widget.jobProviderId,
        'type': 'job_provider_message',
        'postId': postId,
        'message': text,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'sent',
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Message sent to worker')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to send message: $e')));
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
                  final workerId = msg['workerId'];
                  final postId = msg['postId'];
                  final response = msg['response'];
                  final controller = _chatControllers.putIfAbsent(
                    '$workerId-$postId',
                    () => TextEditingController(),
                  );

                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(msg['message']),
                          const SizedBox(height: 8),
                          Text(
                            'Worker ID: $workerId • Post ID: $postId',
                            style: const TextStyle(fontSize: 12),
                          ),
                          if (msg['timestamp'] != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                _formatTimestamp(msg['timestamp']),
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          if (response == 'interested') ...[
                            const Divider(height: 16),
                            TextField(
                              controller: controller,
                              decoration: InputDecoration(
                                labelText: 'Send a message to worker',
                                border: OutlineInputBorder(),
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.send),
                                  onPressed: () {
                                    final text = controller.text.trim();
                                    if (text.isNotEmpty) {
                                      _sendMessageToWorker(
                                        workerId: workerId,
                                        postId: postId,
                                        text: text,
                                      );
                                      controller.clear();
                                    }
                                  },
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
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
