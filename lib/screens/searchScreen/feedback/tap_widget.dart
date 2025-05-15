import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'feedback_function.dart';
import '../../../utils/providers/feedback_provider.dart';

class tapWidget extends StatefulWidget {
  const tapWidget({
    super.key,
    required this.navState,
    required this.firestore,
    required this.authentication,
    required this.tts,
  });

  final Map<String, dynamic> navState;
  final FirebaseFirestore firestore;
  final FirebaseAuth authentication;
  final FlutterTts tts;

  @override
  State<tapWidget> createState() => _tapWidgetState();
}

class _tapWidgetState extends State<tapWidget>
    with SingleTickerProviderStateMixin {
  String userGroup = '';
  int featureIndex = 0;
  bool resetToggle = true;

  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;

  final List<String> featureTexts = [
    '이 길의 풍경이 만족스럽다면\n더블탭 해주세요!',
    '이 길이 안전하다면\n더블탭 해주세요!',
    '이 길의 현재 통행량이\n많으면 더블탭 해주세요!',
    '이 길이 빠르다고 생각하신다면\n더블탭 해주세요!.',
    '주행 중인 길에\n신호등이 많이 없다면\n더블탭 해주세요!',
    '이 길의 오르막이 심하면\n더블탭 해주세요!',
    '이 길이 안전하다고 생각되면\n더블탭 해주세요!',
    '이 길이 자전거길이라면\n더블탭 해주세요!',
  ];

  final List<String> ttsTexts = [
    '이 길의 풍경이 만족스럽다면 더블탭 해주세요!',
    '이 길이 안전하다면 더블탭 해주세요!',
    '이 길의 현재 통행량이 많으면 더블탭 해주세요!',
    '이 길이 빠르다고 생각하신다면 더블탭 해주세요!.',
    '주행 중인 길에 신호등이 많이 없다면 더블탭 해주세요!',
    '이 길의 오르막이 심하면 더블탭 해주세요!',
    '이 길이 안전하다고 생각되면 더블탭 해주세요!',
    '이 길이 자전거길이라면 더블탭 해주세요!',
  ];

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 800),
    );

    _slideAnimation = Tween<Offset>(
      begin: Offset(0, -1), // 위에서 시작
      end: Offset(0, 0), // 제자리
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward(); // 애니메이션 시작

    resetToggle = true;
    widget.firestore
        .collection('users')
        .doc(widget.authentication.currentUser?.uid)
        .get()
        .then((value) {
          userGroup = value.data()!['label'].toString();
          print('userGroup : $userGroup');
        });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final FeedbackProvider feedbackProvider = Provider.of<FeedbackProvider>(
      context,
    );
    if (resetToggle) {
      featureIndex = Random().nextInt(8);
      widget.tts.speak(ttsTexts[featureIndex]);
      print('tts : ${ttsTexts[featureIndex]}');
    }

    return Align(
      alignment: Alignment.topCenter, // 상단에 정렬
      child: SlideTransition(
        position: _slideAnimation,
        child: GestureDetector(
          onDoubleTap: () {
            feedback(widget.navState, userGroup, featureIndex);
            resetToggle = false;
            feedbackProvider.pop();
            Navigator.of(context).pop();
          },
          onVerticalDragUpdate: (details) {
            if (details.primaryDelta! < -10) {
              // 위로 스와이프
              resetToggle = false;
              feedbackProvider.pop();
              Navigator.of(context).pop();
            }
          },
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.2, // 좀 더 작게
            margin: EdgeInsets.only(top: 40), // 상단에서 약간 띄우기
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.lightGreen.withOpacity(0.5),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1), // 약하게
                  spreadRadius: 1,
                  blurRadius: 8,
                  offset: Offset(0, 4), // 아래쪽에만
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Expanded(
                  child: Center(
                    child: Text(
                      featureIndex < featureTexts.length
                          ? featureTexts[featureIndex]
                          : 'Double Tap here if you are satisfied with your road!!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Icon(
                  Icons.keyboard_arrow_up,
                  size: 28,
                  color: Colors.white.withOpacity(0.7),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
