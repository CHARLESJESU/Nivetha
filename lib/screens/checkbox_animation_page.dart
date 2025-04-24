import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:nivetha123/Pages/workerpage.dart';
import 'package:nivetha123/screens/user_data.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CheckboxAnimationPage extends StatefulWidget {
  final bool success;
  final UserData? userData; // Made nullable

  const CheckboxAnimationPage({
    Key? key,
    required this.success,
    this.userData, // Optional parameter now
  }) : super(key: key);

  @override
  _CheckboxAnimationPageState createState() => _CheckboxAnimationPageState();
}

class _CheckboxAnimationPageState extends State<CheckboxAnimationPage> {
  bool isChecked = false;

  @override
  void initState() {
    super.initState();

    if (widget.success) {
      Future.delayed(Duration(milliseconds: 300), () {
        setState(() {
          isChecked = true;
        });

        // Navigate to HomeScreen after animation
        Future.delayed(Duration(seconds: 1), () async {
          if (widget.userData != null) {
            final prefs = await SharedPreferences.getInstance();
            String jsonData = jsonEncode(widget.userData!.toJson());
            await prefs.setString('userData', jsonData);
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => Workerpage(userData: widget.userData!),
              ),
            );
          }
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedCheckbox(
              value: isChecked,
              autoPlay: widget.success,
              onChanged: (value) {
                setState(() {
                  isChecked = value;
                });
              },
            ),
            SizedBox(height: 20),
            Text(
              widget.success
                  ? "Registration Successful!"
                  : "Please accept the Terms & Conditions.",
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 30),
            if (!widget.success)
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // Navigate back if unsuccessful
                },
                child: Text("Go Back"),
              )
          ],
        ),
      ),
    );
  }
}

class AnimatedCheckbox extends StatefulWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool autoPlay;

  const AnimatedCheckbox({
    Key? key,
    required this.value,
    required this.onChanged,
    this.autoPlay = true,
  }) : super(key: key);

  @override
  _AnimatedCheckboxState createState() => _AnimatedCheckboxState();
}

class _AnimatedCheckboxState extends State<AnimatedCheckbox>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    if (widget.value && widget.autoPlay) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(covariant AnimatedCheckbox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      widget.value ? _controller.forward() : _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (!widget.autoPlay) return;
    widget.onChanged(!widget.value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: widget.value ? Colors.blue : Colors.grey,
              width: 2.5,
            ),
            color: widget.value ? Colors.blue : Colors.transparent,
          ),
          child: widget.value
              ? Icon(Icons.check, color: Colors.white, size: 35)
              : null,
        ),
      ),
    );
  }
}