import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class AuthServicews {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  // SignUp User
  Future<String> signupUser({
    required String email,
    required String password,
    required String name,
  }) async {
    String res = "Some error occurred";
    try {
      if (email.isNotEmpty && password.isNotEmpty && name.isNotEmpty) {
        // Register user in auth with email and password
        UserCredential cred = await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        // Add user to your Firestore database
        await _firestore.collection("users").doc(cred.user!.uid).set({
          'name': name,
          'uid': cred.user!.uid,
          'email': email,
        });

        res = "success";
      } else {
        res = "Please fill all fields";
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        return "user-not-found"; // Custom error message for existing account
      }
      return e.message ?? "An unknown error occurred"; // Return general error message
    } catch (err) {
      return err.toString(); // Return any other error
    }
    return res;
  }

  // LogIn user
  Future<String> loginUser({
    required String email,
    required String password,
  }) async {
    String res = "Some error occurred";
    String userexist;

    try {
      if (email.isNotEmpty && password.isNotEmpty) {
        // Logging in user with email and password
        await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        final sanitizedEmail = email.replaceAll('.', '_dot_');
        final snapshot = await _database.child("email").child(sanitizedEmail).get();
        if (snapshot.exists) {
          // final storedUserId = snapshot.value;
          userexist="existuser";
        }
        res = "success";
      } else {
        res = "Please enter all the fields";
      }
    } catch (err) {
      return err.toString();
    }
    return res;
  }
  // LogIn user
  Future<String> existUser({
    required String email,
    required String password,
  }) async {

    String userexist="not_existuser";

    try {
      if (email.isNotEmpty && password.isNotEmpty) {

        final sanitizedEmail = email.replaceAll('.', '_dot_');
        final snapshot = await _database.child("email").child(sanitizedEmail).get();
        if (snapshot.exists) {
          final storedUserId = snapshot.value;
          userexist="$storedUserId";
        }

      }
    } catch (err) {
      return err.toString();
    }
    return userexist;
  }
  // For sign-out
  Future<void> signOut() async {
    await _auth.signOut();
  }
}
