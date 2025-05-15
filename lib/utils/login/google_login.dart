import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'social_login.dart';

class GoogleLogin implements SocialLogin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  @override
  Future<bool> login() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        print('사용자가 Google 로그인을 취소함');
        return false;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await _auth.signInWithCredential(credential);
      print('Google 로그인 성공: ${_auth.currentUser?.email}');
      return true;
    } catch (e) {
      print('Google 로그인 실패: $e');
      return false;
    }
  }

  @override
  Future<bool> logout() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
      print('Google 로그아웃 성공');
      return true;
    } catch (e) {
      print('Google 로그아웃 실패: $e');
      return false;
    }
  }
}
