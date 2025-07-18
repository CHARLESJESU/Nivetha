import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../login/Login.dart';
import '../screens/user_data.dart';

// Extension for firstWhereOrNull functionality
extension FirstWhereOrNullExtension<E> on Iterable<E> {
  E? firstWhereOrNull(bool Function(E) test) {
    for (E element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}

class MessageWorkerPage extends StatefulWidget {
  final UserData userData;
  const MessageWorkerPage({Key? key, required this.userData}) : super(key: key);

  @override
  _MessageWorkerPageState createState() => _MessageWorkerPageState();
}

class _MessageWorkerPageState extends State<MessageWorkerPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _messageController = TextEditingController();
  late UserData _userData;
  String? _selectedChatId;
  Map<String, String> _chatNames = {};
  bool _isLoading = true;
  bool _isSending = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _userData = widget.userData;
    _loadChats();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadChats() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final chatsSnapshot =
          await _firestore
              .collection('chats')
              .where('participants', arrayContains: _userData.userId)
              .get();

      final newChatNames = <String, String>{};

      for (final chatDoc in chatsSnapshot.docs) {
        try {
          final participants = List<String>.from(
            chatDoc.data()['participants'] ?? [],
          );
          final otherUserId = participants.firstWhere(
            (id) => id != _userData.userId,
            orElse: () => '',
          );

          if (otherUserId.isNotEmpty) {
            final userDoc =
                await _firestore
                    .collection('users')
                    .doc('jobproviders')
                    .collection('jobproviders')
                    .doc(otherUserId)
                    .get();

            newChatNames[chatDoc.id] =
                userDoc.data()?['name'] ?? 'Unknown Provider';
          }
        } catch (e) {
          debugPrint('Error processing chat ${chatDoc.id}: $e');
        }
      }

      setState(() {
        _chatNames = newChatNames;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load chats. Please try again.';
        _isLoading = false;
      });
      debugPrint('Error loading chats: $e');
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.isEmpty || _selectedChatId == null) return;

    setState(() => _isSending = true);

    try {
      await _firestore
          .collection('chats')
          .doc(_selectedChatId)
          .collection('messages')
          .add({
            'senderId': _userData.userId,
            'text': _messageController.text,
            'timestamp': FieldValue.serverTimestamp(),
          });

      _messageController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send message: ${e.toString()}')),
      );
    } finally {
      setState(() => _isSending = false);
    }
  }

  Future<void> _startNewChat(String jobProviderId) async {
    try {
      setState(() => _isLoading = true);

      // Check for existing chat using firstWhereOrNull
      final existingChat =
          await _firestore
              .collection('chats')
              .where('participants', arrayContains: _userData.userId)
              .get();

      // Using our extension method to safely find or return null
      final chatDoc = existingChat.docs.firstWhereOrNull((doc) {
        final participants = List<String>.from(
          doc.data()['participants'] ?? [],
        );
        return participants.contains(jobProviderId);
      });

      String? chatId = chatDoc?.id;

      // Create new chat if doesn't exist
      if (chatId == null) {
        final newChat = await _firestore.collection('chats').add({
          'participants': [_userData.userId, jobProviderId],
          'createdAt': FieldValue.serverTimestamp(),
        });
        chatId = newChat.id;

        // Get provider name
        final providerDoc =
            await _firestore
                .collection('users')
                .doc('jobproviders')
                .collection('jobproviders')
                .doc(jobProviderId)
                .get();

        setState(() {
          _chatNames[chatId!] =
              providerDoc.data()?['name'] ?? 'Unknown Provider';
        });
      }

      setState(() {
        _selectedChatId = chatId;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to start chat. Please try again.';
        _isLoading = false;
      });
      debugPrint('Error starting new chat: $e');
    }
  }

  Widget _buildChatList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_errorMessage!),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadChats, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_chatNames.isEmpty) {
      return const Center(
        child: Text('No chats available. Start a new conversation!'),
      );
    }

    return ListView.builder(
      itemCount: _chatNames.length,
      itemBuilder: (context, index) {
        final chatId = _chatNames.keys.elementAt(index);
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: Text(
              _chatNames[chatId]!,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            onTap: () => setState(() => _selectedChatId = chatId),
          ),
        );
      },
    );
  }

  Widget _buildMessageList() {
    return StreamBuilder<QuerySnapshot>(
      stream:
          _selectedChatId != null
              ? _firestore
                  .collection('chats')
                  .doc(_selectedChatId)
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots()
              : null,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final messages = snapshot.data!.docs;

        if (messages.isEmpty) {
          return const Center(
            child: Text('No messages yet. Start the conversation!'),
          );
        }

        return ListView.builder(
          reverse: true,
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final message = messages[index].data() as Map<String, dynamic>;
            final isMe = message['senderId'] == _userData.userId;

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              child: Row(
                mainAxisAlignment:
                    isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                children: [
                  Flexible(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 300),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color:
                            isMe
                                ? Theme.of(context).primaryColor
                                : Colors.grey[300],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!isMe)
                            Text(
                              _chatNames[_selectedChatId] ?? 'Provider',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isMe ? Colors.white : Colors.black,
                              ),
                            ),
                          Text(
                            message['text'] ?? '',
                            style: TextStyle(
                              color: isMe ? Colors.white : Colors.black,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatTimestamp(message['timestamp']),
                            style: TextStyle(
                              color: isMe ? Colors.white70 : Colors.black54,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return '';

    try {
      final date =
          timestamp is Timestamp
              ? timestamp.toDate()
              : DateTime.parse(timestamp.toString());
      return '${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return '';
    }
  }

  Future<void> _showProviderSelection() async {
    final selectedProvider = await showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text("Select Job Provider"),
            content: FutureBuilder<QuerySnapshot>(
              future:
                  _firestore
                      .collection('users')
                      .doc('jobproviders')
                      .collection('jobproviders')
                      .get(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Text('Error: ${snapshot.error}');
                }

                final providers = snapshot.data!.docs;

                return SizedBox(
                  width: double.maxFinite,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: providers.length,
                    itemBuilder: (context, index) {
                      final provider = providers[index];
                      return ListTile(
                        leading: const Icon(Icons.person),
                        title: Text(provider['name'] ?? 'Unknown Provider'),
                        onTap: () => Navigator.pop(context, provider.id),
                      );
                    },
                  ),
                );
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          ),
    );

    if (selectedProvider != null) {
      await _startNewChat(selectedProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _selectedChatId != null
              ? _chatNames[_selectedChatId] ?? 'Chat'
              : 'Messages',
        ),
        actions: [
          if (_selectedChatId != null)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => setState(() => _selectedChatId = null),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child:
                _selectedChatId == null
                    ? _buildChatList()
                    : _buildMessageList(),
          ),
          if (_selectedChatId != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        border: const OutlineInputBorder(),
                        suffixIcon:
                            _isSending
                                ? const Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                                : null,
                      ),
                      enabled: !_isSending,
                    ),
                  ),
                  const SizedBox(width: 8),
                  FloatingActionButton(
                    mini: true,
                    child: const Icon(Icons.send),
                    onPressed: _isSending ? null : _sendMessage,
                  ),
                ],
              ),
            ),
        ],
      ),
      floatingActionButton:
          _selectedChatId == null
              ? FloatingActionButton(
                child: const Icon(Icons.add),
                onPressed: _showProviderSelection,
              )
              : null,
    );
  }
}
