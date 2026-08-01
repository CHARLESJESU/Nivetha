import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import '../jobprovider/jobprovider_home.dart';
import '../worker/worker_home.dart';
import '../../services/authentication.dart';
import '../../main.dart';
import '../onboarding/name_job.dart';
import '../../models/user_data.dart';
import 'signup.dart';
import 'forgot_password.dart'; // Import the new ForgotPasswordScreen
import '../../theme/branding.dart';
import '../../services/notification_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final FocusNode passwordFocusNode = FocusNode();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final _formKey = GlobalKey<FormState>();
  bool isLoading = false;
  bool _isPasswordVisible = false;
  String errorMessage = ''; // Store error message here

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    passwordFocusNode.dispose();
    super.dispose();
  }

  void loginUser() async {
    if (_formKey.currentState!.validate()) {
      setState(() => isLoading = true);
      String res = await AuthServicews().loginUser(
        email: emailController.text,
        password: passwordController.text,
      );
      String userexist = await AuthServicews().existUser(
        email: emailController.text,
        password: passwordController.text,
      );
      String userType;
      if (res == "success" && userexist == "not_existuser") {
        // if (res == "success") {
        globalEmail = emailController.text;
        setState(() {
          isLoading = false;
          errorMessage = '';
        });
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => Page1NameRole(userData: UserData()),
          ),
        );
      } else if (res == "success") {
        setState(() {
          isLoading = false;
          errorMessage = '';
        });
        if (userexist.startsWith("JO")) {
          userType = "jobproviders";
        } else {
          userType = "workers";
        }
        final snapshot =
            await _firestore
                .collection('users')
                .doc(userType)
                .collection(
                  userType,
                ) // Assuming nested subcollection with same name
                .doc(userexist)
                .get();

        final data = snapshot.data() as Map<String, dynamic>;
        //
        // Now you can use `data['fieldName']` safely
        // Ensure correct type
        final userData = UserData.fromJson(data);
        await NotificationService.init(userId: userexist);
        // Navigator.of(context).pushReplacement(
        //
        //   MaterialPageRoute(
        //     builder: (context) => Hida(userexist: userType),
        //   ),
        // );
        Widget nextPage =
            userType == 'workers'
                ? Workerpage(userData: userData)
                : Jobproviderpage(userData: userData);

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => nextPage),
        );
      } else {
        setState(() {
          isLoading = false;
          errorMessage =
              'User ID or Password is incorrect'; // Update error message
        });
        passwordController.clear();
        FocusScope.of(context).requestFocus(passwordFocusNode);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    double height = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: WNColors.bg,
      body: SingleChildScrollView(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 40.0,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const WNLogo(size: 140),

                  const SizedBox(height: 28),
                  const Text(
                    "Welcome Back!",
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: WNColors.navy,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Log in to your account to continue",
                    style: TextStyle(fontSize: 15, color: Colors.black54),
                  ),
                  const SizedBox(height: 32),
                  _buildTextField(
                    emailController,
                    'Email',
                    Icons.email_outlined,
                  ),
                  const SizedBox(height: 20),
                  _buildTextField(
                    passwordController,
                    'Password',
                    Icons.lock_outline,
                    isPass: true,
                    focusNode: passwordFocusNode,
                  ),

                  // Display the error message if present
                  if (errorMessage.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Text(
                        errorMessage,
                        style: const TextStyle(color: Colors.red, fontSize: 16),
                      ),
                    ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ForgotPasswordScreen(),
                          ),
                        );
                      },

                      child: const Text(
                        "Forgot Password?",
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: WNColors.blue,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  _buildElevatedButton("Log In", isLoading ? null : loginUser, isLoading),
                  const SizedBox(height: 30),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        "Don't have an account?",
                        style: TextStyle(fontSize: 14),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SignUpScreen(),
                            ),
                          );
                        },
                        child: const Text(
                          " Sign Up",
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: WNColors.blue,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hintText,
    IconData icon, {
    bool isPass = false,
    FocusNode? focusNode,
  }) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      obscureText: isPass ? !_isPasswordVisible : false,
      style: const TextStyle(fontSize: 16),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please fill this field';
        }
        return null;
      },
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: WNColors.blue),
        suffixIcon: isPass
            ? IconButton(
                icon: Icon(
                  _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                  color: WNColors.blue,
                ),
                onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
              )
            : null,
        hintText: hintText,
        hintStyle: const TextStyle(color: Colors.black45, fontSize: 16),
        border: OutlineInputBorder(
          borderSide: BorderSide.none,
          borderRadius: BorderRadius.circular(14),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide.none,
          borderRadius: BorderRadius.circular(14),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: WNColors.blue, width: 2),
          borderRadius: BorderRadius.circular(14),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 14,
          horizontal: 16,
        ),
      ),
    );
  }

  Widget _buildElevatedButton(String text, VoidCallback? onTap, bool loading) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: WNColors.blue,
          disabledBackgroundColor: WNColors.blue.withOpacity(0.7),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: loading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                text,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }
}
