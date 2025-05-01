import 'package:flutter/material.dart';
import 'package:nivetha123/screens/user_data.dart';
import '../widgets/step_progress.dart';
import 'contact_details.dart';

class Page2PersonalDetails extends StatefulWidget {
  final UserData userData;
  Page2PersonalDetails({required this.userData});

  @override
  _Page2PersonalDetailsState createState() => _Page2PersonalDetailsState();
}

class _Page2PersonalDetailsState extends State<Page2PersonalDetails> {
  final List<String> genders = ['Male', 'Female', 'Other'];
  DateTime? selectedDate;
  String? errorMessage;

  void _validateAndProceed() {
    if (widget.userData.gender == null || selectedDate == null) {
      setState(() {
        errorMessage = 'Please select gender and date of birth';
      });
      return;
    }

    if (widget.userData.role == 'Worker') {
      DateTime today = DateTime.now();
      int age = today.year - selectedDate!.year;
      if (selectedDate!.month > today.month ||
          (selectedDate!.month == today.month &&
              selectedDate!.day > today.day)) {
        age--;
      }

      if (age < 18) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Workers must be 18+ to proceed!')),
        );
        return;
      }
    }

    // ✅ Delay navigation so user can see the message
    Future.delayed(Duration(seconds: 0), () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => Page3ContactDetails(userData: widget.userData),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          'Personal Info',
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StepProgress(currentStep: 2, totalSteps: 5),

                  SizedBox(height: 30),

                  // Gender Selection
                  Text(
                    'Select Gender',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 10),
                  Column(
                    children:
                        genders.map((String gender) {
                          return RadioListTile<String>(
                            title: Text(gender, style: TextStyle(fontSize: 16)),
                            value: gender,
                            groupValue: widget.userData.gender,
                            onChanged: (String? value) {
                              setState(() {
                                widget.userData.gender = value!;
                                errorMessage = null;
                              });
                            },
                            activeColor: Colors.blue,
                          );
                        }).toList(),
                  ),

                  SizedBox(height: 30),

                  // Date of Birth Picker
                  Text(
                    'Date of Birth',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 15),
                  InkWell(
                    onTap: () async {
                      DateTime? pickedDate = await showDatePicker(
                        context: context,
                        initialDate: DateTime(2000),
                        firstDate: DateTime(1900),
                        lastDate: DateTime.now(),
                      );
                      if (pickedDate != null) {
                        setState(() {
                          selectedDate = pickedDate;
                          widget.userData.dob = pickedDate;
                          errorMessage = null;
                        });
                      }
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 15,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            selectedDate == null
                                ? 'Select Date'
                                : '${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                          ),
                          Icon(Icons.calendar_today, color: Colors.blue),
                        ],
                      ),
                    ),
                  ),

                  // Error Message
                  if (errorMessage != null)
                    Padding(
                      padding: EdgeInsets.only(top: 10),
                      child: Text(
                        errorMessage!,
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Fixed Navigation Buttons
          Padding(
            padding: EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                  ),
                  icon: Icon(Icons.arrow_back, color: Colors.white),
                  label: Text('Back', style: TextStyle(color: Colors.white)),
                ),
                ElevatedButton.icon(
                  onPressed: _validateAndProceed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                  ),
                  icon: Icon(Icons.arrow_forward, color: Colors.white),
                  label: Text('Next', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
