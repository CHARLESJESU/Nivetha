import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class WorkerMessagesPage extends StatefulWidget {
  final String workerId;

  const WorkerMessagesPage({super.key, required this.workerId});

  @override
  State<WorkerMessagesPage> createState() => _WorkerMessagesPageState();
}

class _WorkerMessagesPageState extends State<WorkerMessagesPage> {
  String? _activePostIdForChat;
  String? _activeJobProviderId;
  final TextEditingController _chatController = TextEditingController();

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
                                onPressed: () {
                                  setState(() {
                                    _activePostIdForChat = postId;
                                    _activeJobProviderId = from;
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
                                onPressed:
                                    () => _sendResponseToJobProvider(
                                      jobProviderId: from,
                                      workerResponse: 'not_interested',
                                      postId: postId,
                                    ),
                                icon: const Icon(Icons.thumb_down),
                                label: const Text("Not interested"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_activePostIdForChat == postId) ...[
                          const SizedBox(height: 12),
                          TextField(
                            controller: _chatController,
                            decoration: InputDecoration(
                              labelText: "Send a message to the job provider",
                              border: OutlineInputBorder(),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.send),
                                onPressed: () {
                                  final chatText = _chatController.text.trim();
                                  if (chatText.isNotEmpty) {
                                    _sendResponseToJobProvider(
                                      jobProviderId: _activeJobProviderId!,
                                      workerResponse: 'interested',
                                      postId: _activePostIdForChat!,
                                      additionalMessage: chatText,
                                    );
                                    _chatController.clear();
                                    setState(() {
                                      _activePostIdForChat = null;
                                      _activeJobProviderId = null;
                                    });
                                  }
                                },
                              ),
                            ),
                          ),
                        ],
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
    String? additionalMessage,
  }) async {
    final responseRef = FirebaseFirestore.instance
        .collection('messages')
        .doc(jobProviderId)
        .collection('inbox');

    final baseMessage =
        workerResponse == 'interested'
            ? 'I am interested in this job.'
            : 'I am not interested in this job.';

    try {
      await responseRef.add({
        'from': widget.workerId,
        'type': 'worker_response',
        'postId': postId,
        'response': workerResponse,
        'timestamp': FieldValue.serverTimestamp(),
        'message':
            additionalMessage != null
                ? '$baseMessage\n\nAdditional message: $additionalMessage'
                : baseMessage,
        'status': 'sent',
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Response sent to job provider (${workerResponse.replaceAll('_', ' ')})',
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to send response: $e')));
    }
  }
}
