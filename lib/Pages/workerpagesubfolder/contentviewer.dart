// lib/worker/worker_content_view.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart'; // Keep for location lookup

// Your existing imports for models and utilities
import 'package:nivetha123/Pages/workerpagesubfolder/workerjobprovider.dart'; // Assuming this is your JobProvider model
import 'package:nivetha123/Pages/workerpagesubfolder/workerpost.dart'; // Assuming this is your Post model


import '../map_pages.dart'; // Your existing MapPage

class WorkerContentView extends StatelessWidget {
  final List<Post> posts;
  final bool isLoading;
  final Map<String, bool> appliedJobs;
  final Map<String, JobProvider> jobProviderDetails;
  final String? selectedCity;
  final List<String> availableCities;
  final ValueChanged<String?> onCityChanged;
  final Future<void> Function(String jobProviderUserId, String postId) onApplyForJob;
  final Future<void> Function() onRefreshPosts; // Callback to refresh posts


  const WorkerContentView({
    Key? key,
    required this.posts,
    required this.isLoading,
    required this.appliedJobs,
    required this.jobProviderDetails,
    required this.selectedCity,
    required this.availableCities,
    required this.onCityChanged,
    required this.onApplyForJob,
    required this.onRefreshPosts, // Initialize the callback
  }) : super(key: key);


  @override
  Widget build(BuildContext context) {
    final filteredPosts = selectedCity == null
        ? posts
        : posts.where((post) {
      final provider = jobProviderDetails[post.userId];
      return provider?.city == selectedCity;
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: DropdownButton<String?>(
            value: selectedCity,
            hint: const Text("Filter by City"),
            isExpanded: true,
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text("All Cities"),
              ),
              ...availableCities.map(
                    (city) => DropdownMenuItem<String?>(value: city, child: Text(city)),
              ),
            ],
            onChanged: onCityChanged, // Use the callback
          ),
        ),
        Expanded(
          child: RefreshIndicator( // Keep RefreshIndicator here for refreshing content view
            onRefresh: onRefreshPosts,
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredPosts.isEmpty
                ? const Center(child: Text("No jobs available for selected city."))
                : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: filteredPosts.length,
              itemBuilder: (context, index) {
                final post = filteredPosts[index];
                final isApplied = appliedJobs[post.postId] ?? false;
                final provider = jobProviderDetails[post.userId];
                final providerAddress = provider?.address ?? "";

                return Card(
                  color: const Color(0xFFF2F2F2),
                  margin: const EdgeInsets.only(bottom: 16),
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Job Provider Id: ${post.userId}",
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.blueAccent,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.location_on,
                                color: Colors.redAccent,
                              ),
                              onPressed: () async {
                                if (providerAddress.isNotEmpty) {
                                  try {
                                    List<Location> locations =
                                    await locationFromAddress(providerAddress);
                                    if (locations.isNotEmpty) {
                                      final lat = locations[0].latitude;
                                      final lng = locations[0].longitude;
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => MapPage(
                                            latitude: lat,
                                            longitude: lng,
                                            address: providerAddress,
                                          ),
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    print("Error getting location: $e");
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text("Couldn't find location for the given address"),
                                      ),
                                    );
                                  }
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text("Address is empty")),
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "City: ${provider?.city ?? ''}",
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.blueAccent,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (post.imageBase64.isNotEmpty)
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => Scaffold(
                                        appBar: AppBar(
                                          backgroundColor: Colors.black,
                                          iconTheme: const IconThemeData(
                                            color: Colors.white,
                                          ),
                                        ),
                                        backgroundColor: Colors.black,
                                        body: Center(
                                          child: InteractiveViewer(
                                            child: Image.memory(
                                              base64Decode(post.imageBase64),
                                              fit: BoxFit.contain,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.memory(
                                    base64Decode(post.imageBase64),
                                    height: 100,
                                    width: 100,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    post.description,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: ElevatedButton.icon(
                                      onPressed: isApplied
                                          ? null
                                          : () => onApplyForJob(
                                        post.userId,
                                        post.postId,
                                      ),
                                      icon: const Icon(Icons.work, color: Colors.white),
                                      label: Text(
                                        isApplied ? "Applied" : "Apply Now",
                                        style: const TextStyle(color: Colors.white),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                        isApplied ? Colors.grey : Colors.blue,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 10,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
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
        ),
      ],
    );
  }
}