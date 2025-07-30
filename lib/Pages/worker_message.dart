import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class WorkerMessagesPage extends StatefulWidget {
  final String workerId;

  const WorkerMessagesPage({super.key, required this.workerId});

  @override
  State<WorkerMessagesPage> createState() => _WorkerMessagesPageState();
}

class _WorkerMessagesPageState extends State<WorkerMessagesPage> {
  final Map<String, TextEditingController> _chatControllers = {};
  final Map<String, bool> _showChatBox = {};

  @override
  Widget build(BuildContext context) {
    final inboxRef = FirebaseFirestore.instance
        .collection('messages')
        .doc(widget.workerId)
        .collection('inbox')
        .orderBy('timestamp', descending: true);

    return Scaffold(
      appBar: AppBar(title: const Text("Messages")),
      body: StreamBuilder<QuerySnapshot>(
        stream: inboxRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return const Center(child: Text("No messages yet."));
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final from = data['from'] ?? 'Unknown';
              final message = data['message'] ?? '';
              final postId = data['postId'] ?? 'Unknown';
              final type = data['type'] ?? 'general';
              final key = '$from-$postId';

              _chatControllers.putIfAbsent(key, () => TextEditingController());
              _showChatBox.putIfAbsent(key, () => false);

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'From Job Provider: $from',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('Post ID: $postId'),
                      const SizedBox(height: 8),
                      Text(message),
                      const SizedBox(height: 12),
                      if (type == 'job_confirmation') ...[
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  await _sendResponseToJobProvider(
                                    jobProviderId: from,
                                    workerResponse: 'interested',
                                    postId: postId,
                                  );
                                  setState(() {
                                    _showChatBox[key] = true;
                                  });
                                },
                                icon: const Icon(Icons.thumb_up),
                                label: const Text("I'm interested"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  await _sendResponseToJobProvider(
                                    jobProviderId: from,
                                    workerResponse: 'not_interested',
                                    postId: postId,
                                  );
                                  setState(() {
                                    _showChatBox[key] = false;
                                  });
                                },
                                icon: const Icon(Icons.thumb_down),
                                label: const Text("Not interested"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (_showChatBox[key] == true) ...[
                        const Divider(height: 20),
                        TextField(
                          controller: _chatControllers[key],
                          decoration: InputDecoration(
                            labelText: 'Type your message',
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.send),
                              onPressed: () {
                                final text = _chatControllers[key]!.text.trim();
                                if (text.isNotEmpty) {
                                  _sendChatMessage(
                                    postId: postId,
                                    to: from,
                                    message: text,
                                  );
                                  _chatControllers[key]!.clear();
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
                          builder: (context, chatSnapshot) {
                            if (chatSnapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }

                            final chatDocs = chatSnapshot.data?.docs ?? [];

                            return ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: chatDocs.length,
                              itemBuilder: (context, index) {
                                final chat =
                                    chatDocs[index].data()
                                        as Map<String, dynamic>;
                                final isMe = chat['from'] == widget.workerId;
                                final msg = chat['message'] ?? '';
                                final timestamp = chat['timestamp'];
                                final time =
                                    timestamp != null
                                        ? _formatTimestamp(timestamp)
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
                                              ? Colors.blue[100]
                                              : Colors.grey[300],
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(msg),
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
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _sendResponseToJobProvider({
    required String jobProviderId,
    required String workerResponse,
    required String postId,
  }) async {
    final responseRef = FirebaseFirestore.instance
        .collection('messages')
        .doc(jobProviderId)
        .collection('inbox');

    await responseRef.add({
      'from': widget.workerId,
      'type': 'worker_response',
      'postId': postId,
      'response': workerResponse,
      'timestamp': FieldValue.serverTimestamp(),
      'message':
          workerResponse == 'interested'
              ? 'I am interested in this job.'
              : 'I am not interested in this job.',
      'status': 'sent',
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Response sent to job provider (${workerResponse.replaceAll('_', ' ')})',
        ),
      ),
    );
  }

  Future<void> _sendChatMessage({
    required String postId,
    required String to,
    required String message,
  }) async {
    await FirebaseFirestore.instance
        .collection('chats')
        .doc(postId)
        .collection('messages')
        .add({
          'from': widget.workerId,
          'to': to,
          'message': message,
          'timestamp': FieldValue.serverTimestamp(),
        });
  }

  String _formatTimestamp(Timestamp timestamp) {
    final dt = timestamp.toDate();
    return '${dt.year}/${dt.month}/${dt.day} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
