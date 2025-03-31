import 'package:country_state_city_pro/country_state_city_pro.dart';
import 'package:flutter/material.dart';
import 'package:nivetha123/screens/profile_details.dart';
import 'package:nivetha123/screens/summary.dart';
import 'package:nivetha123/screens/user_data.dart';

import '../widgets/step_progress.dart';

class Page3ContactDetails extends StatefulWidget {
  final UserData userData;
  Page3ContactDetails({required this.userData});

  @override
  _Page3ContactDetailsState createState() => _Page3ContactDetailsState();
}

class _Page3ContactDetailsState extends State<Page3ContactDetails> {
  TextEditingController countryController = TextEditingController();
  TextEditingController stateController = TextEditingController();
  TextEditingController cityController = TextEditingController();
  TextEditingController areaController = TextEditingController();
  TextEditingController addressController = TextEditingController();
  TextEditingController phoneController = TextEditingController();

  void _validateAndProceed() {
    String phone = phoneController.text.trim();

    if (phone.isEmpty ||
        areaController.text.isEmpty ||
        addressController.text.isEmpty ||
        countryController.text.isEmpty ||
        stateController.text.isEmpty ||
        cityController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Please enter all details!')));
      return;
    }

    if (phone.length != 10 || !RegExp(r'^[0-9]+$').hasMatch(phone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Enter a valid 10-digit phone number!')),
      );
      return;
    }

    widget.userData.phoneNumber = '+91 ' + phone;
    widget.userData.country = countryController.text;
    widget.userData.state = stateController.text;
    widget.userData.district = cityController.text;
    widget.userData.city = cityController.text;
    widget.userData.area = areaController.text;
    widget.userData.address = addressController.text;

    if (widget.userData.role == 'Worker') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => Page4ProfileDetails(userData: widget.userData),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => Page5Summary(userData: widget.userData),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          'Contact Info',
          style: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.blue,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StepProgress(currentStep: 3, totalSteps: 5),

                  SizedBox(height: 20),

                  // 📞 Phone Number Input
                  Text(
                    'Enter your Phone Number',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 10),
                  TextField(
                    controller: phoneController,
                    decoration: InputDecoration(
                      labelText: 'Phone Number',
                      prefixText: '+91 ',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.phone,
                    maxLength: 10,
                  ),

                  SizedBox(height: 10),

                  // 📍 Area Input
                  Text(
                    'Area',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 10),
                  TextField(
                    controller: areaController,
                    decoration: InputDecoration(
                      labelText: 'Enter your Area/Village name',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.text,
                  ),

                  SizedBox(height: 20),

                  // 🏠 Full Address Input
                  Text(
                    'Full Address',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 10),
                  TextField(
                    controller: addressController,
                    decoration: InputDecoration(
                      labelText: 'Door no/Flat no/Street name',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.text,
                  ),

                  SizedBox(height: 20),

                  // 🌍 Country, State, City Picker
                  Text(
                    'Select Country, State & City',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 10),
                  CountryStateCityPicker(
                    country: countryController,
                    state: stateController,
                    city: cityController,
                    dialogColor: Colors.grey.shade200,
                    textFieldDecoration: InputDecoration(
                      fillColor: Colors.grey[200],
                      filled: true,
                      suffixIcon: Icon(Icons.arrow_drop_down),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 🔄 Fixed Navigation Buttons at Bottom
          Padding(
            padding: EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: EdgeInsets.symmetric(vertical: 15),
                    ),
                    child: Text('Back', style: TextStyle(color: Colors.white)),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _validateAndProceed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: EdgeInsets.symmetric(vertical: 15),
                    ),
                    child: Text('Next', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
