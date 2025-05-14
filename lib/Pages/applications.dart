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
  List<bool> showDetails = [];

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
        showDetails = List.generate(fetchedApps.length, (_) => false);
      });
    }
  }

  Widget _buildWorkerCard(Map<String, dynamic> data, int index) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top: ID + Name
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "User ID: ${data['userId']}",
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                Text(
                  "Name: ${data['name']}",
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ],
            ),

            SizedBox(height: 10),

            // Expanded Details
            if (showDetails[index])
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _detailText("Experience", data['experience']),
                  _detailText("Role", data['role']),
                  _detailText("Gender", data['gender']),
                  _detailText("DOB", data['dob']),
                  _detailText("Country", data['country']),
                  _detailText("State", data['state']),
                  _detailText("District", data['district']),
                  _detailText("City", data['city']),
                  _detailText("Area", data['area']),
                  _detailText("Address", data['address']),
                  SizedBox(height: 8),
                ],
              ),

            // Accept/Reject Buttons only visible when details are expanded
            if (showDetails[index])
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text("Accept",style: TextStyle(color: Colors.white),),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text("Reject",style: TextStyle(color: Colors.white),),
                    ),
                  ),
                ],
              ),

            // More Details moved to bottom
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    showDetails[index] = !showDetails[index];
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    showDetails[index] ? "Hide details" : "More details",
                    style: TextStyle(color: Colors.blue, fontSize: 14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailText(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Text(
        "$label: $value",
        style: TextStyle(fontSize: 13, color: Colors.black87),
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
          return _buildWorkerCard(applications[index], index);
        },
      ),
    );
  }
}