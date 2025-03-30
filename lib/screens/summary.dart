import 'package:flutter/material.dart';
import 'package:nivetha123/screens/user_data.dart';
import 'dart:io';

import '../widgets/step_progress.dart';

class Page5Summary extends StatefulWidget {
  final UserData userData;
  Page5Summary({required this.userData});

  @override
  _Page5SummaryState createState() => _Page5SummaryState();
}

class _Page5SummaryState extends State<Page5Summary> {
  bool termsAccepted = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          'Profile Overview',
          style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        // Ensures all content is scrollable
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StepProgress(currentStep: 5, totalSteps: 5),

              SizedBox(height: 20),

              Text(
                'Review Your Details',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Divider(),

              // 📸 Profile Picture Review
              Center(
                child: Container(
                  padding: EdgeInsets.all(2), // Border thickness
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.black,
                      width: 1,
                    ), // Black border
                  ),
                  child: CircleAvatar(
                    radius: 65,
                    backgroundColor: Colors.grey[200],
                    backgroundImage:
                        widget.userData.profileImage != null
                            ? FileImage(File(widget.userData.profileImage!))
                            : null,
                    child:
                        widget.userData.profileImage == null
                            ? Icon(Icons.person, size: 65, color: Colors.blue)
                            : null,
                  ),
                ),
              ),

              SizedBox(height: 20),

              // Personal Information
              Text(
                'Personal Information',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              _buildInfoRow('Name:', widget.userData.name),
              _buildInfoRow('Role:', widget.userData.role),
              _buildInfoRow('Gender:', widget.userData.gender),
              _buildInfoRow(
                'DOB:',
                widget.userData.dob?.toLocal().toString().split(' ')[0] ??
                    "Not Set",
              ),

              SizedBox(height: 20),

              // Contact Information
              Text(
                'Contact Details',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              _buildInfoRow('Phone:', widget.userData.phoneNumber),
              _buildInfoRow('Country:', widget.userData.country),
              _buildInfoRow('State:', widget.userData.state),
              _buildInfoRow('District:', widget.userData.district),
              _buildInfoRow('City:', widget.userData.city),
              _buildInfoRow('Area:', widget.userData.area),
              _buildInfoRow('Address:', widget.userData.address),

              if (widget.userData.role == 'Worker') ...[
                SizedBox(height: 20),
                Text(
                  'Experience',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 10),
                _buildInfoRow(
                  'Years of Experience:',
                  widget.userData.experience,
                ),
              ],

              SizedBox(height: 20),

              // Terms and Conditions Checkbox
              Row(
                children: [
                  Checkbox(
                    value: termsAccepted,
                    onChanged: (value) {
                      setState(() {
                        termsAccepted = value!;
                      });
                    },
                  ),
                  Expanded(child: Text('I accept the Terms & Conditions')),
                ],
              ),

              SizedBox(height: 20),

              // Back & Submit Buttons (Fixed at Bottom)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                      ),
                      child: Text(
                        'Back',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed:
                          termsAccepted
                              ? () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Form Submitted Successfully!',
                                    ),
                                  ),
                                );
                              }
                              : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            termsAccepted ? Colors.blue : Colors.grey,
                      ),
                      child: Text(
                        'Submit',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper method to create information rows
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: FontWeight.bold)),
          Expanded(
            child: Text(
              value.isNotEmpty ? value : 'Not provided',
              textAlign: TextAlign.end,
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }
}
