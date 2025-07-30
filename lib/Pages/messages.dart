import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'jobprovider_chatpage.dart';

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
    final timestamp = FieldValue.serverTimestamp();

    await FirebaseFirestore.instance
        .collection('messages')
        .doc(workerId)
        .collection('inbox')
        .add({
          'from': widget.jobProviderId,
          'type': 'job_provider_message',
          'postId': postId,
          'message': text,
          'timestamp': timestamp,
          'status': 'sent',
        });

    final chatRef = FirebaseFirestore.instance
        .collection('chats')
        .doc(postId)
        .collection('messages');

    await chatRef.add({
      'from': widget.jobProviderId,
      'to': workerId,
      'message': text,
      'timestamp': timestamp,
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Message sent to worker')));
  }

  Future<void> _refresh() async {
    await fetchMessages();
  }

  String _formatTimestamp(Timestamp timestamp) {
    final dateTime = timestamp.toDate();
    return '${dateTime.year}/${dateTime.month}/${dateTime.day} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  void _openChatPage(String workerId, String postId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => ChatPage(
              // 👈 Added
              workerId: workerId,
              jobProviderId: widget.jobProviderId,
              postId: postId,
            ),
      ),
    );
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
                    child: InkWell(
                      // 👈 Added to make tapable
                      onTap:
                          response == 'interested'
                              ? () => _openChatPage(workerId, postId)
                              : null,
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
                                  border: const OutlineInputBorder(),
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
                              const SizedBox(height: 12),
                              StreamBuilder<QuerySnapshot>(
                                stream:
                                    FirebaseFirestore.instance
                                        .collection('chats')
                                        .doc(postId)
                                        .collection('messages')
                                        .orderBy('timestamp')
                                        .snapshots(),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return const Center(
                                      child: CircularProgressIndicator(),
                                    );
                                  }

                                  final chatDocs = snapshot.data?.docs ?? [];

                                  return ListView.builder(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    itemCount: chatDocs.length,
                                    itemBuilder: (context, index) {
                                      final chat =
                                          chatDocs[index].data()
                                              as Map<String, dynamic>;
                                      final isMe =
                                          chat['from'] == widget.jobProviderId;
                                      final msgText = chat['message'] ?? '';
                                      final time =
                                          chat['timestamp'] != null
                                              ? _formatTimestamp(
                                                chat['timestamp'],
                                              )
                                              : '';

                                      return Align(
                                        alignment:
                                            isMe
                                                ? Alignment.centerRight
                                                : Alignment.centerLeft,
                                        child: Container(
                                          margin: const EdgeInsets.symmetric(
                                            vertical: 4,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color:
                                                isMe
                                                    ? Colors.green[100]
                                                    : Colors.grey[300],
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                msgText,
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                time,
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.black54,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
    );
  }
}
