import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class GoogleLoginProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool isLogined = false;
  User? user;

  Future<void> login() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return;

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final result = await _auth.signInWithCredential(credential);
      user = result.user;
      isLogined = true;

      await _checkUserExist();

      notifyListeners();
    } catch (e) {
      print('Google 로그인 실패: $e');
      isLogined = false;
      user = null;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
    isLogined = false;
    user = null;
    notifyListeners();
  }

  Future<void> _checkUserExist() async {
    final docRef = _firestore.collection('users').doc(user?.uid);
    final snapshot = await docRef.get();

    if (!snapshot.exists) {
      await docRef.set({
        'uid': user?.uid,
        'email': user?.email ?? '',
        'fullname': user?.displayName ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'totalDistance': 0,
        'attributes': {
          "scenery": 0,
          "safety": 0,
          "traffic": 0,
          "fast": 0,
          "signal": 0,
          "uphill": 0,
          "bigRoad": 0,
          "bikePath": 0,
        }
      });
    }
  }
}
