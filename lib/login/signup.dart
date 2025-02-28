import 'package:flutter/material.dart';

import '../authendication/authentication.dart';
import 'Login.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool isLoading = false;
  bool _isPasswordVisible = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    nameController.dispose();
    super.dispose();
  }

  void signUpUser() async {
    if (_formKey.currentState!.validate()) {
      setState(() => isLoading = true);

      String res = await AuthServicews().signupUser(
        email: emailController.text,
        password: passwordController.text,
        name: nameController.text,
      );

      if (res == "success") {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      } else {
        _showErrorDialog(res);
      }

      setState(() => isLoading = false);
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Error"),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("OK"),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    bool isPass = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextFormField(
        controller: controller,
        obscureText: isPass ? !_isPasswordVisible : false,
        style: const TextStyle(fontSize: 18),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please fill this field';
          }
          if (hintText == 'Enter your email' &&
              !RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
            return 'Invalid email address';
          }
          if (hintText == 'Enter your password' && !isValidPassword(value)) {
            return 'Password must include at least 1 letter, 1 number, and 1 special character.';
          }
          return null;
        },
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.blueGrey),
          suffixIcon: isPass
              ? IconButton(
            icon: Icon(
              _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
              color: Colors.blueGrey,
            ),
            onPressed: () {
              setState(() {
                _isPasswordVisible = !_isPasswordVisible;
              });
            },
          )
              : null,
          hintText: hintText,
          hintStyle: const TextStyle(color: Colors.grey, fontSize: 16),
          enabledBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Colors.blueGrey),
            borderRadius: BorderRadius.circular(10),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Colors.blue, width: 2),
            borderRadius: BorderRadius.circular(10),
          ),
          filled: true,
          fillColor: const Color(0xFFF5F5F5),
        ),
      ),
    );
  }

  bool isValidPassword(String password) {
    return RegExp(r'^(?=.*[A-Za-z])(?=.*\d)(?=.*[@\$!%*?&])[A-Za-z\d@$!%*?&]{8,}$')
        .hasMatch(password);
  }

  Widget _buildButton({
    required VoidCallback onTap,
    required String text,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 15),
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 30),
        ),
        child: Text(
          text,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold,color: Colors.white),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double height = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: height / 4,
                    child: Image.asset("assets/images/signup1.jpg"),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "Create Your Account Details",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildTextField(
                    controller: nameController,
                    hintText: 'Enter your name',
                    icon: Icons.person,
                  ),
                  _buildTextField(
                    controller: emailController,
                    hintText: 'Enter your email',
                    icon: Icons.email,
                  ),
                  _buildTextField(
                    controller: passwordController,
                    hintText: 'Enter your password',
                    icon: Icons.lock,
                    isPass: true,
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: _buildButton(
                      onTap: signUpUser,
                      text: "Sign Up",
                    ),
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "Already have an account? ",
                          style: TextStyle(fontSize: 16, color: Colors.black54),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const LoginScreen(),
                            ),
                          ),
                          child: const Text(
                            "Login",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
