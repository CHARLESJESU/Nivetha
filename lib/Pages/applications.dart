import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class ApplicationsPage extends StatefulWidget {
  final String jobProviderUserId;

  ApplicationsPage({required this.jobProviderUserId});

  @override
  _ApplicationsPageState createState() => _ApplicationsPageState();
}

class _ApplicationsPageState extends State<ApplicationsPage> {
  List<Map<String, dynamic>> applications = [];

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

    final snapshot = await ref.get();

    if (snapshot.exists) {
      final data = snapshot.value as Map<dynamic, dynamic>;
      List<Map<String, dynamic>> fetchedApps = [];

      data.forEach((workerUserId, workerData) {
        if (workerData is Map<dynamic, dynamic>) {
          fetchedApps.add({
            'userId': workerUserId,
            'name': workerData['name'] ?? 'N/A',
            'phoneNumber': workerData['phoneNumber'] ?? 'N/A',
            'experience': workerData['experience'] ?? 'N/A',
            'role': workerData['role'] ?? 'N/A',
            'gender': workerData['gender'] ?? 'N/A',
            'dob': workerData['dob'] ?? 'N/A',
            'country': workerData['country'] ?? 'N/A',
            'state': workerData['state'] ?? 'N/A',
            'district': workerData['district'] ?? 'N/A',
            'city': workerData['city'] ?? 'N/A',
            'area': workerData['area'] ?? 'N/A',
            'address': workerData['address'] ?? 'N/A',
          });
        }
      });

      setState(() {
        applications = fetchedApps;
      });
    }
  }

  Widget _buildWorkerCard(Map<String, dynamic> data) {
    return Card(
      margin: EdgeInsets.all(12),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "User ID: ${data['userId']}",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 4),
            Text("Name: ${data['name']}"),
            Text("Phone: ${data['phoneNumber']}"),
            Text("Experience: ${data['experience']}"),
            Text("Role: ${data['role']}"),
            Text("Gender: ${data['gender']}"),
            Text("DOB: ${data['dob']}"),
            Text("Country: ${data['country']}"),
            Text("State: ${data['state']}"),
            Text("District: ${data['district']}"),
            Text("City: ${data['city']}"),
            Text("Area: ${data['area']}"),
            Text("Address: ${data['address']}"),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Applications')),
      body:
          applications.isEmpty
              ? Center(child: Text('No applications yet'))
              : ListView.builder(
                itemCount: applications.length,
                itemBuilder: (context, index) {
                  return _buildWorkerCard(applications[index]);
                },
              ),
    );
  }
}
