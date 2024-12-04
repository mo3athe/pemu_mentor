import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import 'package:flutter/foundation.dart';
import '../screens/home/mentor/mentor_home_screen.dart';
import '../screens/home/mentee/mentee_home_screen.dart';
import '../screens/auth/login_screen.dart'; // Import LoginScreen

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  UserModel? _currentUser;

  UserModel? get currentUser => _currentUser;

  // Get current user
  UserModel? _userFromFirebase(User? user) {
    return user != null
        ? UserModel(
            id: user.uid,
            name: '',
            // These will be populated from Firestore
            email: user.email ?? '',
            username: '',
            role: '',
            isActive: true,
          )
        : null;
  }

  // Stream to listen to auth state changes
  Stream<UserModel?> get userStream =>
      _auth.authStateChanges().asyncMap((user) async {
        if (user == null) {
          _currentUser = null;
          return null;
        }

        final userData =
            await _firestore.collection('users').doc(user.uid).get();
        if (!userData.exists) {
          return null;
        }

        _currentUser = UserModel.fromMap({
          'id': user.uid,
          ...userData.data()!,
        });
        return _currentUser;
      });

  // Register with email and password
  Future<UserModel?> registerUser({
    required String name,
    required String email,
    required String username,
    required String password,
    required String role,
  }) async {
    try {
      print('Starting user registration process...');
      print('Email: $email, Username: $username, Role: $role');

      // Validate inputs
      if (email.isEmpty ||
          password.isEmpty ||
          name.isEmpty ||
          username.isEmpty) {
        print('Error: Required fields are empty');
        return null;
      }

      // Create user in Firebase Auth
      print('Creating user in Firebase Auth...');
      final UserCredential authResult =
          await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      print('Auth result: ${authResult.user?.uid}');

      if (authResult.user == null) {
        print('Error: User creation returned null');
        return null;
      }

      // Create user data
      final userData = {
        'id': authResult.user!.uid,
        'name': name.trim(),
        'email': email.trim(),
        'username': username.trim(),
        'role': role,
        'isActive': true,
      };

      print('User data prepared: $userData');

      try {
        print('Attempting to save user data to Firestore...');
        // Save user data to Firestore with explicit error handling
        final DocumentReference docRef =
            _firestore.collection('users').doc(authResult.user!.uid);

        await docRef.set(userData).timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            throw TimeoutException('Firestore operation timed out');
          },
        );

        print('Successfully saved user data to Firestore');

        // Verify the data was saved
        final docSnapshot = await docRef.get();
        if (!docSnapshot.exists) {
          print('Error: Document was not created in Firestore');
          throw Exception('Document was not created in Firestore');
        }

        print('Successfully verified user data in Firestore');

        // Return user model
        return UserModel(
          id: authResult.user!.uid,
          name: name.trim(),
          email: email.trim(),
          username: username.trim(),
          role: role,
          isActive: true,
        );
      } catch (firestoreError) {
        print('Detailed Firestore Error: $firestoreError');
        if (firestoreError is FirebaseException) {
          print('Firebase Error Code: ${firestoreError.code}');
          print('Firebase Error Message: ${firestoreError.message}');
        }
        // Clean up: Delete the auth user since Firestore failed
        try {
          print('Attempting to delete auth user due to Firestore failure...');
          await authResult.user!.delete();
          print('Successfully deleted auth user');
        } catch (deleteError) {
          print('Error deleting auth user: $deleteError');
        }
        return null;
      }
    } on FirebaseAuthException catch (e) {
      print('Firebase Auth Error: ${e.code} - ${e.message}');
      return null;
    } catch (e) {
      print('General Error: $e');
      return null;
    }
  }

  // Sign in with email and password
  Future<UserModel?> signInWithEmail(String email, String password) async {
    try {
      final UserCredential authResult = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      if (authResult.user == null) {
        print('Error: Sign in returned null user');
        return null;
      }

      // Get user data from Firestore
      final DocumentSnapshot doc =
          await _firestore.collection('users').doc(authResult.user!.uid).get();

      if (!doc.exists) {
        print('Error: User document not found in Firestore');
        return null;
      }

      return UserModel.fromMap(doc.data() as Map<String, dynamic>);
    } on FirebaseAuthException catch (e) {
      print('Firebase Auth Error: ${e.code} - ${e.message}');
      return null;
    } catch (e) {
      print('General Error: $e');
      return null;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      _currentUser = null;
      notifyListeners();
    } catch (e) {
      print('Sign out error: $e');
      rethrow;
    }
  }

  // Reset password
  Future<bool> resetPassword(String email) async {
    if (email.isEmpty) {
      print('Error: Email is empty');
      return false;
    }

    try {
      // Sign out current user if any
      if (_auth.currentUser != null) {
        await _auth.signOut();
      }

      // Send password reset email
      await _auth.sendPasswordResetEmail(
        email: email.trim(),
        actionCodeSettings: ActionCodeSettings(
          url: 'https://pemuapp.page.link/reset-password',
          handleCodeInApp: true,
          androidPackageName: 'com.example.pemu_mentor',
          androidInstallApp: true,
          androidMinimumVersion: '1',
        ),
      );
      return true;
    } on FirebaseAuthException catch (e) {
      print('Firebase Auth Error: ${e.code} - ${e.message}');
      return false;
    } catch (e) {
      print('General Error: $e');
      return false;
    }
  }

  Future<void> updateUserInfo(UserModel updatedUser) async {
    try {
      await _firestore.collection('users').doc(updatedUser.id).update({
        'name': updatedUser.name,
        'email': updatedUser.email,
        'username': updatedUser.username,
        // Add other fields as needed
      });
      _currentUser = updatedUser;
      notifyListeners();
    } catch (e) {
      print('Error updating user info: $e');
      throw Exception('Failed to update user information');
    }
  }

  void navigateToHomeScreen(BuildContext context, UserModel user) {
    if (user.role.toLowerCase() == 'mentor') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => MentorHomeScreen(user: user),
        ),
      );
    } else if (user.role.toLowerCase() == 'mentee') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => MenteeHomeScreen(user: user),
        ),
      );
    }
  }

  void navigateBasedOnRole(BuildContext context, UserModel user) {
    if (user.role.toLowerCase() == 'mentor') {
      Navigator.pushReplacementNamed(
        context,
        '/mentor_home',
        arguments: user,
      );
    } else if (user.role.toLowerCase() == 'mentee') {
      Navigator.pushReplacementNamed(
        context,
        '/mentee_home',
        arguments: user,
      );
    }
  }
}
