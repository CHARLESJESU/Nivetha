import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/branding.dart';
import '../shared/chat_page.dart';

class WorkerMessagesPage extends StatefulWidget {
  final String workerId;

  const WorkerMessagesPage({super.key, required this.workerId});

  @override
  State<WorkerMessagesPage> createState() => _WorkerMessagesPageState();
}

class _WorkerMessagesPageState extends State<WorkerMessagesPage> {
  // Cache of already-known responses so re-renders don't re-query Firestore;
  // the actual source of truth is always Firestore, not local state, since
  // this page gets rebuilt fresh every time the worker switches tabs.
  final Map<String, String?> _responseCache = {};
  final Set<String> _respondingKeys = {};

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
      'message': workerResponse == 'interested'
          ? 'I am interested in this job.'
          : 'I am not interested in this job.',
      'status': 'sent',
    });
  }

  Future<String?> _fetchExistingResponse({
    required String jobProviderId,
    required String postId,
  }) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('messages')
        .doc(jobProviderId)
        .collection('inbox')
        .where('from', isEqualTo: widget.workerId)
        .where('postId', isEqualTo: postId)
        .where('type', isEqualTo: 'worker_response')
        .get();

    if (snapshot.docs.isEmpty) return null;
    return snapshot.docs.first.data()['response'] as String?;
  }

  void _navigateToChat(String postId, String to) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatPage(postId: postId, myId: widget.workerId, peerId: to),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final inboxRef = FirebaseFirestore.instance
        .collection('messages')
        .doc(widget.workerId)
        .collection('inbox')
        .orderBy('timestamp', descending: true);

    return Container(
      color: WNColors.bg,
      child: StreamBuilder<QuerySnapshot>(
        stream: inboxRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: WNColors.blue));
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          color: WNColors.blue.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.mail_outline_rounded, size: 44, color: WNColors.blue),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No messages yet',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: WNColors.navy),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Job providers will message you here after you apply.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final from = data['from'] ?? 'Unknown';
              final message = data['message'] ?? '';
              final postId = data['postId'] ?? 'Unknown';
              final type = data['type'] ?? 'general';
              final key = '$from-$postId';

              return Card(
                color: Colors.white,
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'From Job Provider',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: WNColors.navy),
                      ),
                      const SizedBox(height: 4),
                      Text('Post ID: $postId', style: const TextStyle(fontSize: 12, color: Colors.black45)),
                      const SizedBox(height: 8),
                      Text(message, style: const TextStyle(fontSize: 14, color: Colors.black87)),
                      const SizedBox(height: 12),
                      if (type == 'job_confirmation') ...[
                        FutureBuilder<String?>(
                          future: _responseCache.containsKey(key)
                              ? Future.value(_responseCache[key])
                              : _fetchExistingResponse(jobProviderId: from, postId: postId)
                                  .then((value) {
                                  _responseCache[key] = value;
                                  return value;
                                }),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: Center(
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: WNColors.blue),
                                  ),
                                ),
                              );
                            }

                            final existingResponse = snapshot.data;

                            if (existingResponse == 'interested') {
                              return Row(
                                children: [
                                  const Icon(Icons.check_circle, color: WNColors.blue, size: 18),
                                  const SizedBox(width: 6),
                                  const Text("You're interested", style: TextStyle(color: WNColors.blue, fontWeight: FontWeight.w600)),
                                  const Spacer(),
                                  TextButton.icon(
                                    onPressed: () => _navigateToChat(postId, from),
                                    icon: const Icon(Icons.chat_bubble_outline, size: 18, color: WNColors.blue),
                                    label: const Text("Open Chat", style: TextStyle(color: WNColors.blue)),
                                  ),
                                ],
                              );
                            }

                            if (existingResponse == 'not_interested') {
                              return const Row(
                                children: [
                                  Icon(Icons.cancel_outlined, color: Colors.black45, size: 18),
                                  SizedBox(width: 6),
                                  Text("You declined this job", style: TextStyle(color: Colors.black45, fontWeight: FontWeight.w600)),
                                ],
                              );
                            }

                            final isResponding = _respondingKeys.contains(key);

                            Future<void> respond(String response) async {
                              setState(() => _respondingKeys.add(key));
                              try {
                                await _sendResponseToJobProvider(
                                  jobProviderId: from,
                                  workerResponse: response,
                                  postId: postId,
                                );
                                if (!mounted) return;
                                setState(() => _responseCache[key] = response);
                                if (response == 'interested') _navigateToChat(postId, from);
                              } finally {
                                if (mounted) setState(() => _respondingKeys.remove(key));
                              }
                            }

                            return Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: isResponding ? null : () => respond('interested'),
                                    icon: isResponding
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                          )
                                        : const Icon(Icons.chat_bubble_outline, size: 18, color: Colors.white),
                                    label: const Text("I'm interested", style: TextStyle(color: Colors.white)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: WNColors.blue,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: isResponding ? null : () => respond('not_interested'),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: Colors.black26),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    child: isResponding
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black45),
                                          )
                                        : const Text("Not interested", style: TextStyle(color: Colors.black54)),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ] else if (type == 'worker_response') ...[
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () => _navigateToChat(postId, from),
                            icon: const Icon(Icons.chat_bubble_outline, size: 18, color: WNColors.blue),
                            label: const Text("Open Chat", style: TextStyle(color: WNColors.blue)),
                          ),
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
}
