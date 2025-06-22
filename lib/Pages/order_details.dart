import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:photo_view/photo_view.dart';
import 'package:google_fonts/google_fonts.dart';

class Order {
  final String id;
  final String orderId;
  final String description;
  final String imageBase64;

  Order({
    required this.id,
    required this.orderId,
    required this.description,
    required this.imageBase64,
  });
}

class OrderDetailsPage extends StatefulWidget {
  final String userId;

  OrderDetailsPage({required this.userId});

  @override
  _OrderDetailsPageState createState() => _OrderDetailsPageState();
}

class _OrderDetailsPageState extends State<OrderDetailsPage> {
  List<Order> orders = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    final userId = widget.userId;

    try {
      final ordersRef = FirebaseDatabase.instance.ref().child(
        'jobs/workers/$userId',
      );
      final snapshot = await ordersRef.get();

      List<Order> fetchedOrders = [];
      if (snapshot.exists) {
        final orderData = snapshot.value as Map<dynamic, dynamic>;

        orderData.forEach((key, value) {
          if (value is Map<dynamic, dynamic>) {
            fetchedOrders.add(
              Order(
                id: key,
                orderId: value['orderId']?.toString() ?? key,
                description: value['description'] ?? '',
                imageBase64: value['imageBase64'] ?? '',
              ),
            );
          }
        });
      }

      fetchedOrders.sort((a, b) => b.id.compareTo(a.id));

      setState(() {
        orders = fetchedOrders;
        isLoading = false;
      });
    } catch (e) {
      print("Failed to load orders: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  Uint8List _decodeBase64(String base64String) {
    try {
      return base64Decode(base64String);
    } catch (e) {
      print("Base64 decoding failed: $e");
      return Uint8List(0);
    }
  }

  void _openFullImage(String base64Image) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => FullImagePage(imageBytes: _decodeBase64(base64Image)),
      ),
    );
  }

  Future<void> _deleteOrder(String postId) async {
    try {
      await FirebaseDatabase.instance
          .ref()
          .child('jobs/workers/${widget.userId}/$postId')
          .remove();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Deleted successfully")));
      _loadOrders();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to delete: ${e.toString()}")),
      );
    }
  }

  Future<void> _editOrder(String postId, String currentDescription) async {
    TextEditingController _editController = TextEditingController(
      text: currentDescription,
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Edit Description"),
          content: TextField(
            controller: _editController,
            maxLines: 3,
            decoration: InputDecoration(labelText: 'Enter new description'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                String newDescription = _editController.text;
                if (newDescription.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Description cannot be empty")),
                  );
                  return;
                }

                try {
                  await FirebaseDatabase.instance
                      .ref()
                      .child('jobs/workers/${widget.userId}/$postId')
                      .update({'description': newDescription});

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Updated successfully")),
                  );
                  Navigator.pop(context);
                  _loadOrders();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Failed to update: ${e.toString()}"),
                    ),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _loadOrders,
        child: orders.isEmpty
            ? ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 120),
            Icon(Icons.inbox_rounded, size: 80, color: Colors.grey),
            SizedBox(height: 12),
            Center(
              child: Text(
                "No orders found",
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ),
          ],
        )
            : ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final order = orders[index];
            return Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 5,
              margin: const EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            "Order ID: ${order.orderId}",
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[800],
                            ),
                          ),
                        ),
                        PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'edit') {
                              _editOrder(order.id, order.description);
                            } else if (value == 'delete') {
                              _deleteOrder(order.id);
                            }
                          },
                          icon: const Icon(Icons.more_vert),
                          itemBuilder: (BuildContext context) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Text('Edit'),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('Delete'),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        InkWell(
                          onTap: () => _openFullImage(order.imageBase64),
                          borderRadius: BorderRadius.circular(12),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: order.imageBase64.isNotEmpty
                                ? Image.memory(
                              _decodeBase64(order.imageBase64),
                              width: 100,
                              height: 100,
                              fit: BoxFit.cover,
                            )
                                : Container(
                              width: 100,
                              height: 100,
                              color: Colors.grey[200],
                              child: const Icon(Icons.image_not_supported, color: Colors.grey),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              order.description,
                              style: GoogleFonts.poppins(fontSize: 14),
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );

  }
}

class FullImagePage extends StatelessWidget {
  final Uint8List imageBytes;

  FullImagePage({required this.imageBytes});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Full Image")),
      body: PhotoView(
        imageProvider: MemoryImage(imageBytes),
        backgroundDecoration: BoxDecoration(color: Colors.black),
        minScale: PhotoViewComputedScale.contained,
        maxScale: PhotoViewComputedScale.covered * 2,
      ),
    );
  }
}
