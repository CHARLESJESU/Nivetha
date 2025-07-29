import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MessageWorkerPage extends StatefulWidget {
  final String workerId;
  final String workerName;
  final String jobProviderId;
  final String jobProviderName;

  const MessageWorkerPage({
    Key? key,
    required this.workerId,
    required this.workerName,
    required this.jobProviderId,
    required this.jobProviderName,
  }) : super(key: key);

  @override
  _MessageWorkerPageState createState() => _MessageWorkerPageState();
}

class _MessageWorkerPageState extends State<MessageWorkerPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _markMessagesAsRead();
  }

  Future<void> _markMessagesAsRead() async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    final unreadMessages =
        await _firestore
            .collection('messages')
            .doc('worker_${widget.workerId}')
            .collection('chats')
            .where('isRead', isEqualTo: false)
            .where('senderId', isEqualTo: widget.jobProviderId)
            .get();

    final batch = _firestore.batch();
    for (final doc in unreadMessages.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Messages with ${widget.workerName}'),
        actions: [
          IconButton(icon: Icon(Icons.refresh), onPressed: _markMessagesAsRead),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream:
                  _firestore
                      .collection('messages')
                      .doc('worker_${widget.workerId}')
                      .collection('chats')
                      .orderBy('timestamp', descending: true)
                      .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(child: Text('No messages yet'));
                }

                final messages = snapshot.data!.docs;

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollController.hasClients) {
                    _scrollController.animateTo(
                      0,
                      duration: Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                  }
                });

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message =
                        messages[index].data() as Map<String, dynamic>;
                    final isMe = message['senderId'] == widget.jobProviderId;
                    final isRead = message['isRead'] ?? false;
                    final senderType = message['senderType'] ?? '';

                    return Column(
                      children: [
                        if (!isMe && index == messages.length - 1)
                          _buildQuickReplyButtons(),
                        Container(
                          margin: EdgeInsets.symmetric(
                            vertical: 4,
                            horizontal: 8,
                          ),
                          alignment:
                              isMe
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                          child: Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isMe ? Colors.blue[100] : Colors.grey[200],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (!isMe)
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${message['senderName'] ?? 'Unknown'} (ID: ${message['senderId'] ?? 'N/A'})',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color:
                                              senderType == 'job_provider'
                                                  ? Colors.blue
                                                  : Colors.green,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                    ],
                                  ),
                                Text(message['text'] ?? ''),
                                SizedBox(height: 4),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _formatTimestamp(message['timestamp']),
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    if (isMe && isRead)
                                      Icon(
                                        Icons.done_all,
                                        size: 12,
                                        color: Colors.blue,
                                      ),
                                    if (isMe && !isRead)
                                      Icon(
                                        Icons.done,
                                        size: 12,
                                        color: Colors.grey,
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildQuickReplyButtons() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            onPressed: () {
              _messageController.text = "Yes, I'm interested";
              _sendMessage();
            },
            child: Text("Yes, I'm Interested"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            onPressed: () {
              _messageController.text = "No, I'm not interested";
              _sendMessage();
            },
            child: Text("No, I'm Not Interested"),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Padding(
      padding: EdgeInsets.all(8.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12),
              ),
              maxLines: null,
              keyboardType: TextInputType.multiline,
            ),
          ),
          IconButton(icon: Icon(Icons.send), onPressed: () => _sendMessage()),
        ],
      ),
    );
  }

  Future<void> _sendMessage() async {
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty) return;

    final user = _auth.currentUser;
    if (user == null) return;

    final messageData = {
      'text': messageText,
      'senderId': widget.jobProviderId,
      'senderName': widget.jobProviderName,
      'senderType': 'job_provider',
      'receiverType': 'worker',
      'timestamp': Timestamp.now(),
      'isRead': false,
    };

    try {
      // Save message to worker's chat collection
      await _firestore
          .collection('messages')
          .doc('worker_${widget.workerId}')
          .collection('chats')
          .add(messageData);

      // Also save to job provider's collection for their reference
      await _firestore
          .collection('messages')
          .doc('jobprovider_${widget.jobProviderId}')
          .collection('chats')
          .add({...messageData, 'isRead': true, 'workerId': widget.workerId});

      _messageController.clear();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to send message: $e')));
    }
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return '';

    DateTime dateTime;
    if (timestamp is Timestamp) {
      dateTime = timestamp.toDate();
    } else if (timestamp is int) {
      dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    } else {
      return '';
    }

    return '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
