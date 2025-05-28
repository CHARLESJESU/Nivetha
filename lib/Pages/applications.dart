import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class ApplicationsPage extends StatefulWidget {
  final String jobProviderUserId;

  const ApplicationsPage({required this.jobProviderUserId, super.key});

  @override
  _ApplicationsPageState createState() => _ApplicationsPageState();
}

class _ApplicationsPageState extends State<ApplicationsPage> {
  Map<String, List<Map<String, dynamic>>> groupedApplications = {};
  List<bool> showOrderDetails = [];

  @override
  void initState() {
    super.initState();
    fetchApplications();
  }

  Future<void> fetchApplications() async {
    final ref = FirebaseDatabase.instance
        .ref()
        .child('applications')
        .child(widget.jobProviderUserId);

    try {
      final snapshot = await ref.get();

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>?;
        Map<String, List<Map<String, dynamic>>> tempGroupedApps = {};

        if (data != null) {
          data.forEach((orderId, orderData) {
            if (orderData is Map<dynamic, dynamic>) {
              List<Map<String, dynamic>> workers = [];
              orderData.forEach((workerUserId, workerData) {
                if (workerData is Map<dynamic, dynamic>) {
                  workers.add({
                    'userId': workerUserId.toString(),
                    'name': workerData['name']?.toString() ?? 'N/A',
                    'phoneNumber':
                        workerData['phoneNumber']?.toString() ?? 'N/A',
                    'experience': workerData['experience']?.toString() ?? 'N/A',
                    'role': workerData['role']?.toString() ?? 'N/A',
                    'gender': workerData['gender']?.toString() ?? 'N/A',
                    'dob': workerData['dob']?.toString() ?? 'N/A',
                    'country': workerData['country']?.toString() ?? 'N/A',
                    'state': workerData['state']?.toString() ?? 'N/A',
                    'district': workerData['district']?.toString() ?? 'N/A',
                    'city': workerData['city']?.toString() ?? 'N/A',
                    'area': workerData['area']?.toString() ?? 'N/A',
                    'address': workerData['address']?.toString() ?? 'N/A',
                    'status': workerData['status']?.toString() ?? 'applied',
                    'showDetails': false,
                  });
                }
              });
              tempGroupedApps[orderId.toString()] = workers;
            }
          });
        }

        setState(() {
          groupedApplications = tempGroupedApps;
          showOrderDetails = List.generate(
            tempGroupedApps.length,
            (_) => false,
          );
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load applications: $e')),
      );
    }
  }

  Future<void> updateApplicationStatus(
    String orderId,
    String workerUserId,
    String newStatus,
  ) async {
    try {
      final ref = FirebaseDatabase.instance
          .ref()
          .child('applications')
          .child(widget.jobProviderUserId)
          .child(orderId)
          .child(workerUserId)
          .child('status');

      await ref.set(newStatus);

      setState(() {
        final workers = groupedApplications[orderId];
        if (workers != null) {
          final workerIndex = workers.indexWhere(
            (w) => w['userId'] == workerUserId,
          );
          if (workerIndex != -1) {
            workers[workerIndex]['status'] = newStatus;
          }
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Application ${newStatus.toLowerCase()} successfully'),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to update status: $e')));
    }
  }

  Widget _buildOrderCard(
    String orderId,
    List<Map<String, dynamic>> workers,
    int orderIndex,
  ) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ExpansionTile(
        title: Text(
          'Order ID: $orderId',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.blueAccent,
          ),
        ),
        subtitle: Text(
          '${workers.length} Applicant${workers.length == 1 ? '' : 's'}',
          style: const TextStyle(fontSize: 14, color: Colors.grey),
        ),
        initiallyExpanded: showOrderDetails[orderIndex],
        onExpansionChanged: (expanded) {
          setState(() {
            showOrderDetails[orderIndex] = expanded;
          });
        },
        children:
            workers.asMap().entries.map((entry) {
              int workerIndex = entry.key;
              Map<String, dynamic> worker = entry.value;
              return _buildWorkerCard(worker, orderIndex, workerIndex, orderId);
            }).toList(),
      ),
    );
  }

  Widget _buildWorkerCard(
    Map<String, dynamic> worker,
    int orderIndex,
    int workerIndex,
    String orderId,
  ) {
    bool showDetails = worker['showDetails'] ?? false;
    String status = worker['status'] ?? 'applied';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          worker['name'] ?? 'N/A',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'User ID: ${worker['userId'] ?? 'N/A'}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      showDetails ? Icons.expand_less : Icons.expand_more,
                      color: Colors.blue,
                    ),
                    onPressed: () {
                      setState(() {
                        final workers = groupedApplications[orderId];
                        if (workers != null && workers.length > workerIndex) {
                          workers[workerIndex]['showDetails'] = !showDetails;
                        }
                      });
                    },
                  ),
                ],
              ),
              if (showDetails)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _detailText('Phone', worker['phoneNumber'] ?? 'N/A'),
                      _detailText('Experience', worker['experience'] ?? 'N/A'),
                      _detailText('Role', worker['role'] ?? 'N/A'),
                      _detailText('Gender', worker['gender'] ?? 'N/A'),
                      _detailText('DOB', worker['dob'] ?? 'N/A'),
                      _detailText('Country', worker['country'] ?? 'N/A'),
                      _detailText('State', worker['state'] ?? 'N/A'),
                      _detailText('District', worker['district'] ?? 'N/A'),
                      _detailText('City', worker['city'] ?? 'N/A'),
                      _detailText('Area', worker['area'] ?? 'N/A'),
                      _detailText('Address', worker['address'] ?? 'N/A'),
                      _detailText('Status', status),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed:
                                  status == 'applied'
                                      ? () => updateApplicationStatus(
                                        orderId,
                                        worker['userId'],
                                        'accepted',
                                      )
                                      : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text(
                                'Accept',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed:
                                  status == 'applied'
                                      ? () => updateApplicationStatus(
                                        orderId,
                                        worker['userId'],
                                        'rejected',
                                      )
                                      : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text(
                                'Reject',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailText(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Job Applications'),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body:
          groupedApplications.isEmpty
              ? const Center(child: Text('No applications yet'))
              : ListView.builder(
                itemCount: groupedApplications.length,
                itemBuilder: (context, index) {
                  String orderId = groupedApplications.keys.elementAt(index);
                  final workers = groupedApplications[orderId] ?? [];
                  return _buildOrderCard(orderId, workers, index);
                },
              ),
    );
  }
}
