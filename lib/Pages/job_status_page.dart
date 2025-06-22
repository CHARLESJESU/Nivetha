import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../screens/user_data.dart';

class JobStatusPage extends StatefulWidget {
  final UserData userData;

  const JobStatusPage({Key? key, required this.userData}) : super(key: key);

  @override
  _JobStatusPageState createState() => _JobStatusPageState();
}

class _JobStatusPageState extends State<JobStatusPage> {
  List<Map<String, dynamic>> jobList = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchAppliedJobs();
  }

  Future<void> fetchAppliedJobs() async {
    try {
      final ref = FirebaseDatabase.instance.ref(
        'appliedJobs/${widget.userData.userId}',
      );
      final snapshot = await ref.get();

      if (snapshot.exists) {
        List<Map<String, dynamic>> jobs = [];
        final data = snapshot.value as Map<dynamic, dynamic>;

        data.forEach((jobProviderId, posts) {
          if (posts is Map<dynamic, dynamic>) {
            posts.forEach((postId, jobData) {
              jobs.add({
                'jobProviderId': jobProviderId,
                'postId': postId,
                'description': jobData['description'] ?? '',
                'imageBase64': jobData['imageBase64'] ?? '',
                'status': jobData['status'] ?? 'applied',
              });
            });
          }
        });

        setState(() {
          jobList = jobs;
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      print("Error fetching applied jobs: $e");
      setState(() => isLoading = false);
    }
  }

  Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  IconData getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      default:
        return Icons.hourglass_top;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : jobList.isEmpty
              ? const Center(child: Text('No job applications found.'))
              : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: jobList.length,
                itemBuilder: (context, index) {
                  final job = jobList[index];
                  final statusColor = getStatusColor(job['status']);
                  final statusIcon = getStatusIcon(job['status']);
                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Job ID: ${job['postId']}",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (job['imageBase64'] != null &&
                              job['imageBase64'].toString().isNotEmpty)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.memory(
                                base64Decode(job['imageBase64']),
                                height: 120,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                          const SizedBox(height: 8),
                          Text(
                            "Description: ${job['description']}",
                            style: const TextStyle(fontSize: 14),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(statusIcon, color: statusColor),
                              const SizedBox(width: 6),
                              Text(
                                "Status: ${job['status'].toString().toUpperCase()}",
                                style: TextStyle(
                                  color: statusColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
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
