import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nivetha123/Pages/worker_chatpage.dart';

class WorkerMessagesPage extends StatefulWidget {
  final String workerId;

  const WorkerMessagesPage({super.key, required this.workerId});

  @override
  State<WorkerMessagesPage> createState() => _WorkerMessagesPageState();
}

class _WorkerMessagesPageState extends State<WorkerMessagesPage> {
  final Set<String> _sentInterest = {}; // Tracks post IDs already responded to
  final Set<String> _notInterestedSent = {};

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

              final hasSentInterested = _sentInterest.contains(key);
              final hasSentNotInterested = _notInterestedSent.contains(key);

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
                                onPressed:
                                    hasSentInterested
                                        ? null
                                        : () async {
                                          final alreadySent =
                                              await _checkIfAlreadySent(
                                                jobProviderId: from,
                                                postId: postId,
                                              );

                                          if (alreadySent) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'You have already sent your interest.',
                                                ),
                                              ),
                                            );
                                            _navigateToChat(postId, from);
                                            return;
                                          }

                                          await _sendResponseToJobProvider(
                                            jobProviderId: from,
                                            workerResponse: 'interested',
                                            postId: postId,
                                          );

                                          setState(() {
                                            _sentInterest.add(key);
                                          });

                                          _navigateToChat(postId, from);
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
                                    hasSentNotInterested
                                        ? null
                                        : () async {
                                          await _sendResponseToJobProvider(
                                            jobProviderId: from,
                                            workerResponse: 'not_interested',
                                            postId: postId,
                                          );

                                          setState(() {
                                            _notInterestedSent.add(key);
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

  Future<bool> _checkIfAlreadySent({
    required String jobProviderId,
    required String postId,
  }) async {
    final snapshot =
        await FirebaseFirestore.instance
            .collection('messages')
            .doc(jobProviderId)
            .collection('inbox')
            .where('from', isEqualTo: widget.workerId)
            .where('postId', isEqualTo: postId)
            .where('response', isEqualTo: 'interested')
            .get();

    return snapshot.docs.isNotEmpty;
  }

  void _navigateToChat(String postId, String to) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => ChatPage(postId: postId, myId: widget.workerId, peerId: to),
      ),
    );
  }
}
