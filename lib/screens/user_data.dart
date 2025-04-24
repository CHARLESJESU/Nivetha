class UserData {
  String name = '';
  String role = ''; // Worker or Job Provider
  String gender = '';
  DateTime? dob;
  String country = 'India';
  String state = '';
  String district = '';
  String city = '';
  String address = '';
  String area = '';
  String phoneNumber = '+91';
  String experience = '';
  String profileImage = '';

  // Constructor
  UserData({
    this.name = '',
    this.role = '',
    this.gender = '',
    this.dob,
    this.country = 'India',
    this.state = '',
    this.district = '',
    this.city = '',
    this.address = '',
    this.area = '',
    this.phoneNumber = '+91',
    this.experience = '',
    this.profileImage = '',
  });
// ✅ TO JSON
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'role': role,
      'gender': gender,
      'dob': dob?.toIso8601String(), // Convert DateTime to string
      'country': country,
      'state': state,
      'district': district,
      'city': city,
      'address': address,
      'area': area,
      'phoneNumber': phoneNumber,
      'experience': experience,
      'profileImage': profileImage,
    };
  }

  // ✅ FROM JSON
  factory UserData.fromJson(Map<String, dynamic> json) {
    return UserData(
      name: json['name'] ?? '',
      role: json['role'] ?? '',
      gender: json['gender'] ?? '',
      dob: json['dob'] != null ? DateTime.parse(json['dob']) : null,
      country: json['country'] ?? 'India',
      state: json['state'] ?? '',
      district: json['district'] ?? '',
      city: json['city'] ?? '',
      address: json['address'] ?? '',
      area: json['area'] ?? '',
      phoneNumber: json['phoneNumber'] ?? '+91',
      experience: json['experience'] ?? '',
      profileImage: json['profileImage'] ?? '',
    );
  }

  set contactImage(String contactImage) {}

  set areaAddress(String areaAddress) {}

  // Format user details for UI display
  Map<String, String> getDisplayData() {
    return {
      'Name': name.isNotEmpty ? name : 'Not provided',
      'Role': role.isNotEmpty ? role : 'Not provided',
      'Gender': gender.isNotEmpty ? gender : 'Not provided',
      'Date of Birth':
          dob != null ? '${dob!.toLocal()}'.split(' ')[0] : 'Not provided',
      'Country': country,
      'State': state.isNotEmpty ? state : 'Not provided',
      'District': district.isNotEmpty ? district : 'Not provided',
      'City': city.isNotEmpty ? city : 'Not provided',
      'Address': address.isNotEmpty ? address : 'Not provided',
      'Area': area.isNotEmpty ? area : 'Not provided',
      'Phone Number': phoneNumber.isNotEmpty ? phoneNumber : 'Not provided',
      'Experience': experience.isNotEmpty ? experience : 'Not provided',
    };
  }

  // Reset method
  void reset() {
    name = '';
    role = '';
    gender = '';
    dob = null;
    country = 'India';
    state = '';
    district = '';
    city = '';
    address = '';
    area = '';
    phoneNumber = '+91';
    experience = '';
    profileImage = '';
  }
}
