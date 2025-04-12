import 'package:flutter/material.dart';
import 'package:nivetha123/screens/personal_details.dart';
import 'package:nivetha123/screens/user_data.dart';
import '../widgets/step_progress.dart';

class Page1NameRole extends StatefulWidget {
  final UserData userData;
  Page1NameRole({required this.userData});

  @override
  _Page1NameRoleState createState() => _Page1NameRoleState();
}

class _Page1NameRoleState extends State<Page1NameRole> {
  final _formKey = GlobalKey<FormState>();
  String? selectedRole; // Store the selected role separately for validation

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Full-screen background
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          'User Profile',
          style: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.blue,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    StepProgress(currentStep: 1, totalSteps: 5),

                    SizedBox(height: 30),

                    // Name Input
                    Text(
                      'What Should We Call You?',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 15),
                    TextFormField(
                      decoration: InputDecoration(
                        hintText: 'Your Name',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        filled: true,
                        fillColor: Colors.grey[200],
                      ),
                      validator:
                          (value) =>
                              value == null || value.isEmpty
                                  ? 'Name is required'
                                  : null,
                      onChanged: (value) => widget.userData.name = value,
                    ),

                    SizedBox(height: 30),

                    // Role Selection with Radio Buttons
                    Text(
                      'What is your role?',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 15),
                    Column(
                      children: [
                        RadioListTile<String>(
                          title: Text('Worker', style: TextStyle(fontSize: 16)),
                          value: 'Worker',
                          groupValue: selectedRole,
                          onChanged: (value) {
                            setState(() {
                              selectedRole = value;
                              widget.userData.role = value!;
                            });
                          },
                          activeColor: Colors.blue,
                        ),
                        RadioListTile<String>(
                          title: Text(
                            'Job Provider',
                            style: TextStyle(fontSize: 16),
                          ),
                          value: 'Job Provider',
                          groupValue: selectedRole,
                          onChanged: (value) {
                            setState(() {
                              selectedRole = value;
                              widget.userData.role = value!;
                            });
                          },
                          activeColor: Colors.blue,
                        ),
                      ],
                    ),

                    if (selectedRole ==
                        null) // Show error message if no role selected
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          'Please select a role',
                          style: TextStyle(color: Colors.red, fontSize: 14),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // Fixed Next Button at the Bottom
          Padding(
            padding: EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate() &&
                      selectedRole != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) =>
                                Page2PersonalDetails(userData: widget.userData),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Please enter your name and select a role!',
                        ),
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'Next',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
