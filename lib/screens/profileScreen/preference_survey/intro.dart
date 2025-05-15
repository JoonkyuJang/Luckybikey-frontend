import 'package:flutter/material.dart';

import 'survey.dart';

// 첫 접속 시 안내 페이지 구성
class IntroToSurveyPage extends StatelessWidget {
  final Future<void> Function()? onContinue;

  // onContinue를 선택적 매개변수로 설정
  const IntroToSurveyPage({super.key, this.onContinue});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "나의 자전거 주행 취향 찾기!",
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.lightGreen[900],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Text(
                "사용자님의 주행 스타일에 맞춘 경로를 추천하기 위해 간단한 설문조사를 진행하고자 합니다.",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.lightGreen[700],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.lightGreen,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                ),
                onPressed: () async {
                  // onContinue가 null이 아닐 때만 실행
                  if (onContinue != null) {
                    await onContinue!();
                  }
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) {
                        return PreferenceSurvey();
                      },
                    ),
                  );
                },
                child: const Text(
                  "지금 테스트하기",
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
    );
  }
}
