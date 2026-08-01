import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:photo_view/photo_view.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/branding.dart';
import 'post_job.dart';

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
  StreamSubscription<QuerySnapshot>? _subscription;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _loadOrders() {
    final userId = widget.userId;

    final CollectionReference ordersRef = FirebaseFirestore.instance
        .collection('jobs')
        .doc('workers')
        .collection('workers')
        .doc(userId)
        .collection('order');

    _subscription?.cancel();
    _subscription = ordersRef.snapshots().listen(
      (snapshot) {
        if (!mounted) return;

        List<Order> fetchedOrders = [];
        for (var doc in snapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          fetchedOrders.add(
            Order(
              id: doc.id,
              orderId: data['orderId']?.toString() ?? doc.id,
              description: data['description'] ?? '',
              imageBase64: data['imageBase64'] ?? '',
            ),
          );
        }

        fetchedOrders.sort((a, b) => b.id.compareTo(a.id));

        setState(() {
          orders = fetchedOrders;
          isLoading = false;
        });
      },
      onError: (e) {
        if (!mounted) return;
        setState(() => isLoading = false);
        showWNMessage(context, isError: true, message: "Failed to load orders: $e");
      },
    );
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
      await FirebaseFirestore.instance
          .collection('jobs')
          .doc('workers')
          .collection('workers')
          .doc(widget.userId)
      .collection('order')
      .doc(postId)
          .delete();

      if (mounted) showWNMessage(context, message: "Deleted successfully");

      _loadOrders();
    } catch (e) {
      if (mounted) showWNMessage(context, isError: true, message: "Failed to delete: ${e.toString()}");
    }
  }


  void _editOrder(Order order) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FormPage(
          userId: widget.userId,
          orderId: order.id,
          initialDescription: order.description,
          initialImageBase64: order.imageBase64,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: WNColors.bg,
      child: isLoading
          ? const Center(child: CircularProgressIndicator(color: WNColors.blue))
          : RefreshIndicator(
        color: WNColors.blue,
        onRefresh: () async => _loadOrders(),
        child: orders.isEmpty
            ? ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 120),
            Icon(Icons.inbox_rounded, size: 64, color: Colors.black26),
            SizedBox(height: 12),
            Center(
              child: Text(
                "No orders found",
                style: TextStyle(fontSize: 15, color: Colors.black54),
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
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.all(16),
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
                              color: WNColors.navy,
                            ),
                          ),
                        ),
                        PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'edit') {
                              _editOrder(order);
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
