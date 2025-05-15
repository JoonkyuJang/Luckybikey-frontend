import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';

import 'social_login.dart';


class KakaoLogin implements SocialLogin {
  @override
  Future<bool> login() async {
    try {
      if (await isKakaoTalkInstalled()) {
        // 카카오톡 앱으로 로그인 시도
        try {
          await UserApi.instance.loginWithKakaoTalk();
          print('카카오톡으로 로그인 성공');

          return true;
        } catch (e) {
          print('카카오톡 로그인 실패: $e');
          // 앱 로그인 실패 시 계정으로 로그인 시도
          try {
            await UserApi.instance.loginWithKakaoAccount();
            print('카카오 계정으로 로그인 성공');
            return true;
          } catch (e) {
            print('카카오 계정 로그인 실패: $e');
            return false;
          }
        }
      } else {
        // 카카오톡 미설치: 계정으로 로그인 시도
        try {
          await UserApi.instance.loginWithKakaoAccount();
          print('카카오 계정으로 로그인 성공');
          return true;
        } catch (e) {
          print('카카오 계정 로그인 실패: $e');
          return false;
        }
      }
    } catch (e) {
      print('카카오 로그인 오류: $e');
      return false;
    }
  }

  @override
  Future<bool> logout() async {
    try {
      await UserApi.instance.unlink();
      print('카카오 로그아웃 성공');
      return true;
    } catch (e) {
      print('카카오 로그아웃 실패: $e');
      return false;
    }
  }
}

Future<void> getUserInfo() async {
  try {
    User user = await UserApi.instance.me();
    print('사용자 정보: ${user.kakaoAccount?.profile?.nickname}');
  } catch (e) {
    print('사용자 정보 가져오기 실패: $e');
  }
}

