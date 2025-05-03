import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:photo_view/photo_view.dart';

class Order {
  final String id;
  final String description;
  final String imageBase64;

  Order({
    required this.id,
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

  Uint8List _decodeBase64(String base64String) => base64Decode(base64String);

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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to delete: $e")));
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
              child: Text('Cancel'),
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
                    SnackBar(content: Text("Failed to update: $e")),
                  );
                }
              },
              child: Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(title: Text("My Orders")),
      body:
          isLoading
              ? Center(child: CircularProgressIndicator())
              : orders.isEmpty
              ? Center(child: Text("No orders posted yet."))
              : ListView.builder(
                padding: EdgeInsets.all(12),
                itemCount: orders.length,
                itemBuilder: (context, index) {
                  final order = orders[index];
                  return Card(
                    margin: EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                    child: Padding(
                      padding: EdgeInsets.all(6),
                      child: Column(
                        children: [
                          Align(
                            alignment: Alignment.topRight,
                            child: Padding(
                              padding: EdgeInsets.only(top: 12, right: 8),
                              child: PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'edit') {
                                    _editOrder(order.id, order.description);
                                  } else if (value == 'delete') {
                                    _deleteOrder(order.id);
                                  }
                                },
                                itemBuilder:
                                    (BuildContext context) => [
                                      PopupMenuItem<String>(
                                        value: 'edit',
                                        child: Text('Edit'),
                                      ),
                                      PopupMenuItem<String>(
                                        value: 'delete',
                                        child: Text('Delete'),
                                      ),
                                    ],
                              ),
                            ),
                          ),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              InkWell(
                                onTap: () => _openFullImage(order.imageBase64),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child:
                                      order.imageBase64.isNotEmpty
                                          ? Image.memory(
                                            _decodeBase64(order.imageBase64),
                                            width: 98,
                                            height: 98,
                                            fit: BoxFit.cover,
                                          )
                                          : Container(
                                            width: 98,
                                            height: 98,
                                            color: Colors.grey[200],
                                            child: Center(
                                              child: Text(
                                                "No image",
                                                style: TextStyle(
                                                  color: Colors.grey[700],
                                                ),
                                              ),
                                            ),
                                          ),
                                ),
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Container(
                                  height: 98,
                                  padding: EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    color: Colors.grey[100],
                                  ),
                                  child: SingleChildScrollView(
                                    child: Text(
                                      order.description,
                                      style: TextStyle(fontSize: 14),
                                    ),
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
      body: Container(
        child: PhotoView(
          imageProvider: MemoryImage(imageBytes),
          backgroundDecoration: BoxDecoration(color: Colors.black),
          minScale: PhotoViewComputedScale.contained,
          maxScale: PhotoViewComputedScale.covered * 2,
        ),
      ),
    );
  }
}
