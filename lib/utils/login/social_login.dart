import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';

abstract class SocialLogin {
  Future<bool> login();
  Future<bool> logout();
}

class MainViewModel {
  final SocialLogin _socialLogin;
  bool isLogined = false;
  User? user;

  MainViewModel(this._socialLogin);



  Future login() async {
    isLogined = await _socialLogin.login();
    if (isLogined) {
      user = await UserApi.instance.me();
    }
  }

  Future logout() async {
    await _socialLogin.logout();
    isLogined = false;
    user = null;
  }
}