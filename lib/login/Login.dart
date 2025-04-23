import 'package:flutter/material.dart';

import '../authendication/authentication.dart';
import '../screens/name_job.dart';
import '../screens/user_data.dart';
import 'signup.dart';
import 'forgot_password.dart'; // Import the new ForgotPasswordScreen

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool isLoading = false;
  String errorMessage = ''; // Store error message here

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void loginUser() async {
    if (_formKey.currentState!.validate()) {
      setState(() => isLoading = true);
      String res = await AuthServicews().loginUser(
        email: emailController.text,
        password: passwordController.text,
      );
      if (res == "success") {
        setState(() {
          isLoading = false;
          errorMessage = '';
        });
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => Page1NameRole(userData: UserData()),
          ),
        );
      } else {
        setState(() {
          isLoading = false;
          errorMessage =
              'User ID or Password is incorrect'; // Update error message
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    double height = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
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
                  SizedBox(
                    width: double.infinity,
                    height: height / 4,
                    child: Image.asset("assets/images/login2.png"),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Welcome Back!",
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Log in to your account to continue",
                    style: TextStyle(fontSize: 16, color: Colors.black54),
                  ),
                  const SizedBox(height: 40),
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
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  isLoading
                      ? const CircularProgressIndicator()
                      : _buildElevatedButton("Log In", loginUser),
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
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                            color: Colors.blue,
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
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPass,
      style: const TextStyle(fontSize: 16),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please fill this field';
        }
        return null;
      },
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.blueAccent),
        hintText: hintText,
        hintStyle: const TextStyle(color: Colors.black45, fontSize: 16),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.blueAccent),
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.blue, width: 2),
          borderRadius: BorderRadius.circular(12),
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

  Widget _buildElevatedButton(String text, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
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
