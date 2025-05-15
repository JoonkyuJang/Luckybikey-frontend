import 'package:flutter/material.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_functions/cloud_functions.dart';

// request route 함수 테스트를 위한 위젯
// 출발 지점과 도착 지점의 위도와 경도를 포함한 JSON 객체를 Firebase Functions에 전달합니다.

class RouteRequestWidget extends StatefulWidget {
  const RouteRequestWidget({super.key});

  @override
  _RouteRequestWidgetState createState() => _RouteRequestWidgetState();
}

class _RouteRequestWidgetState extends State<RouteRequestWidget> {
  String _response = 'Initializing Firebase...'; // 초기 상태 메시지
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeFirebase();
  }

  // Firebase 초기화 함수
  Future<void> _initializeFirebase() async {
    await Firebase.initializeApp();
    setState(() {
      _isInitialized = true; // 초기화 완료 상태
      _response = 'Firebase Initialized. Ready to request route.';
    });
  }

  // Firebase Functions 호출 함수
  Future<void> requestRoute() async {
    if (!_isInitialized) return; // 초기화가 완료되지 않은 경우 실행하지 않음

    try {
      final result = await FirebaseFunctions.instance.httpsCallable('request_route').call({
        "StartPoint": {"lat": 37.5322857, "lon": 126.9131594},
        "EndPoint": {"lat": 37.5214849, "lon": 126.9298773},
        "UseSharing": false,
        "UserTaste": false,
      });

      setState(() {
        _response = result.data.toString();
      });
    } on FirebaseFunctionsException catch (error) {
      setState(() {
        _response = "Error: ${error.message}";
      });
      print("Error Code: ${error.code}");
      print("Error Details: ${error.details}");
      print("Error Message: ${error.message}");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Route Request Widget'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: _isInitialized ? requestRoute : null, // 초기화 완료 시에만 버튼 활성화
                child: Text('Request Route'),
              ),
              SizedBox(height: 20),
              Text(
                _response,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
