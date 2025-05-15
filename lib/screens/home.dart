import 'package:flutter/material.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';

import '../../utils/providers/page_provider.dart';

import 'searchScreen/search.dart';
import 'profileScreen/profile.dart';
import 'profileScreen/preference_survey/intro.dart';


class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  // int _selectedIndex = 0; // 현재 선택된 탭 인덱스
  final List<Widget> _pages = [
    HomeContent(),
    Search(),
    Profile(),
  ]; // 페이지 리스트

  // 첫 접속 여부를 확인하는 함수
  Future<bool> checkFirstTimeUser() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool('isFirstTimeUser') ?? true;
  }

  // 첫 접속 완료로 표시하는 함수
  Future<void> setFirstTimeUserCompleted() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isFirstTimeUser', false);
  }

  // 탭 변경 핸들러
  // void _onItemTapped(int index) {
  //   setState(() {
  //     _selectedIndex = index;
  //   });
  // }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: checkFirstTimeUser(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        // 첫 접속이면 안내 페이지를 표시
        if (snapshot.data == true) {
          return IntroToSurveyPage(onContinue: () async {
            await setFirstTimeUserCompleted();
            setState(() {});
          });
        }

        // 첫 접속이 아니라면 기존 정보 화면 표시
        return Scaffold(
          appBar: AppBar(
            centerTitle: true,
            title: const Text(
              "luckybikey",
              style: TextStyle(
                color: Colors.lightGreen,
                fontWeight: FontWeight.bold,
              ),
            ),
            backgroundColor: Colors.white,
            elevation: 0.0,
          ),
          body: Consumer<PageProvider>(
            builder: (context, pageProvider, _) {
              return _pages[pageProvider.currentPage];
            },
          ), // 현재 선택된 페이지를 표시
          //bottomNavigationBar: BottomNavigation(),
        );
      },
    );
  }
}


// 기존 Home의 컨텐츠를 분리한 위젯
class HomeContent extends StatelessWidget {
  const HomeContent({super.key});

  @override
  Widget build(BuildContext context) {
    final pageProvider = Provider.of<PageProvider>(context, listen: false);

    return Column(
      children: [
        Expanded(
          child: Container(
            width: MediaQuery.of(context).size.width,
            color: Colors.lightGreen[100],
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Want to find a way?",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.lightGreen[900],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  "Click here to move to the map.",
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.lightGreen[700],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.lightGreen,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                  ),
                  onPressed: () {
                    pageProvider.setPage(1); // search 페이지로 이동
                  },
                  child: const Text(
                    "Go to Search",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: Container(
            width: MediaQuery.of(context).size.width,
            color: Colors.lightGreen[50],
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Want to choose your preference while riding?",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.lightGreen[900],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  "Click here to move to your profile.",
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.lightGreen[700],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.lightGreen,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                  ),
                  onPressed: () {
                    pageProvider.setPage(2);// profile 페이지로 이동
                  },
                  child: const Text(
                    "Go to Profile",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}