import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class Application {
  final String userId;
  final String name;
  final String phoneNumber;
  final String experience;
  final String role;
  final String gender;
  final String dob;
  final String country;
  final String state;
  final String district;
  final String city;
  final String area;
  final String address;
  String status;
  bool showDetails;

  Application({
    required this.userId,
    required this.name,
    required this.phoneNumber,
    required this.experience,
    required this.role,
    required this.gender,
    required this.dob,
    required this.country,
    required this.state,
    required this.district,
    required this.city,
    required this.area,
    required this.address,
    required this.status,
    this.showDetails = false,
  });

  factory Application.fromMap(String userId, Map<dynamic, dynamic> data) {
    return Application(
      userId: userId,
      name: data['name']?.toString() ?? 'N/A',
      phoneNumber: data['phoneNumber']?.toString() ?? 'N/A',
      experience: data['experience']?.toString() ?? 'N/A',
      role: data['role']?.toString() ?? 'N/A',
      gender: data['gender']?.toString() ?? 'N/A',
      dob: data['dob']?.toString() ?? 'N/A',
      country: data['country']?.toString() ?? 'N/A',
      state: data['state']?.toString() ?? 'N/A',
      district: data['district']?.toString() ?? 'N/A',
      city: data['city']?.toString() ?? 'N/A',
      area: data['area']?.toString() ?? 'N/A',
      address: data['address']?.toString() ?? 'N/A',
      status: data['status']?.toString() ?? 'applied',
    );
  }
}

class ApplicationsPage extends StatefulWidget {
  final String jobProviderUserId;

  const ApplicationsPage({required this.jobProviderUserId, super.key});

  @override
  _ApplicationsPageState createState() => _ApplicationsPageState();
}

class _ApplicationsPageState extends State<ApplicationsPage> {
  Map<String, List<Application>> groupedApplications = {};
  List<bool> showOrderDetails = [];
  bool isLoading = true;
  StreamSubscription<DatabaseEvent>? _subscription;

  @override
  void initState() {
    super.initState();
    fetchApplications();
  }

  Future<void> fetchApplications() async {
    setState(() => isLoading = true);

    final ref = FirebaseFirestore.instance
        .collection('applications')
        .doc(widget.jobProviderUserId)
        .collection('posts'); // adjust if structure differs

    _subscription?.cancel();
    _subscription = ref.snapshots().listen(
          (querySnapshot) async {
        if (!mounted) return;

        Map<String, List<Application>> tempGroupedApps = {};
         print("pdaljkdslflks");
         print(querySnapshot.docs[0]);
        for (var postDoc in querySnapshot.docs) {
          final orderId = postDoc.id;

          // Each post has a subcollection of worker applications
          final workersSnapshot = await postDoc.reference.collection('workers').get();
          List<Application> workers = [];

          for (var workerDoc in workersSnapshot.docs) {
            final workerUserId = workerDoc.id;
            final workerData = workerDoc.data();

            workers.add(Application.fromMap(workerUserId, workerData));
          }

          tempGroupedApps[orderId] = workers;
        }

        setState(() {
          groupedApplications = tempGroupedApps;
          showOrderDetails = List.generate(tempGroupedApps.length, (_) => false);
          isLoading = false;
        });
      },
      onError: (error) {
        if (!mounted) return;
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load applications: $error')),
        );
      },
    ) as StreamSubscription<DatabaseEvent>? ;
  }


  Future<void> updateApplicationStatus(
      String orderId,
      String workerUserId,
      String newStatus,
      ) async {
    try {
      final firestore = FirebaseFirestore.instance;

      // References for both paths to update
      final applicationsRef = firestore
          .collection('applications')
          .doc(widget.jobProviderUserId)
          .collection('posts')
          .doc(orderId)
          .collection('workers')
          .doc(workerUserId);

      final appliedJobsRef = firestore
          .collection('appliedJobs')
          .doc(workerUserId)
          .collection('jobProviders')
          .doc(widget.jobProviderUserId)
          .collection('posts')
          .doc(orderId);

      // Perform batched update to both locations
      WriteBatch batch = firestore.batch();

      batch.update(applicationsRef, {'status': newStatus});
      batch.update(appliedJobsRef, {'status': newStatus});

      await batch.commit();

      // Optional UI update for rejected status
      if (newStatus == 'rejected') {
        setState(() {
          groupedApplications[orderId]!
              .firstWhere((app) => app.userId == workerUserId)
              .showDetails = false;
        });
      }

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


  Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'applied':
        return Colors.blue;
      case 'accepted':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildOrderCard(
    String orderId,
    List<Application> workers,
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
            workers
                .asMap()
                .entries
                .map(
                  (entry) => _buildWorkerCard(
                    entry.value,
                    orderIndex,
                    entry.key,
                    orderId,
                  ),
                )
                .toList(),
      ),
    );
  }

  Widget _buildWorkerCard(
    Application worker,
    int orderIndex,
    int workerIndex,
    String orderId,
  ) {
    bool showDetails = worker.showDetails;
    String status = worker.status;
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
                          worker.name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'User ID: ${worker.userId}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.grey,
                          ),
                        ),
                        Text(
                          'Status: ${worker.status}',
                          style: TextStyle(
                            fontSize: 13,
                            color: getStatusColor(worker.status),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      showDetails ? Icons.expand_less : Icons.expand_more,
                      color: status == 'rejected' ? Colors.grey : Colors.blue,
                    ),
                    onPressed:
                        status == 'rejected'
                            ? null
                            : () {
                              setState(() {
                                groupedApplications[orderId]![workerIndex]
                                    .showDetails = !showDetails;
                              });
                            },
                  ),
                ],
              ),
              if (showDetails && status != 'rejected')
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _detailText('Phone', worker.phoneNumber),
                      _detailText('Experience', worker.experience),
                      _detailText('Role', worker.role),
                      _detailText('Gender', worker.gender),
                      _detailText('DOB', worker.dob),
                      _detailText('Country', worker.country),
                      _detailText('State', worker.state),
                      _detailText('District', worker.district),
                      _detailText('City', worker.city),
                      _detailText('Area', worker.area),
                      _detailText('Address', worker.address),
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
                                        worker.userId,
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
                                        worker.userId,
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

  Widget _detailText(String label, String value, {Color? color}) {
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
              style: TextStyle(fontSize: 13, color: color ?? Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                onRefresh: fetchApplications,
                child:
                    groupedApplications.isEmpty
                        ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: const [
                            SizedBox(height: 150),
                            Center(
                              child: Icon(
                                Icons.work_off,
                                size: 50,
                                color: Colors.grey,
                              ),
                            ),
                            SizedBox(height: 10),
                            Center(child: Text('No applications yet')),
                          ],
                        )
                        : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: groupedApplications.length,
                          itemBuilder: (context, index) {
                            String orderId = groupedApplications.keys.elementAt(
                              index,
                            );
                            final workers = groupedApplications[orderId] ?? [];
                            return _buildOrderCard(orderId, workers, index);
                          },
                        ),
              ),
        ],
      ),
    );
  }
}
