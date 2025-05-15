import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../utils/providers/preference_provider.dart';
import 'survey_result.dart';


final _firestore = FirebaseFirestore.instance;
final _authentication = FirebaseAuth.instance;

class PreferenceSurvey extends StatefulWidget {
  const PreferenceSurvey({super.key});

  @override
  _PreferenceSurveyState createState() => _PreferenceSurveyState();
}

class _PreferenceSurveyState extends State<PreferenceSurvey> {
  final List<Map<String, dynamic>> surveyQuestions = [
    {
      "question": "친구와 자전거 여행을 떠날 때 당신은?",
      "type": "like",
      "keyword": "풍경",
      "options": ["길가에 있는 카페에서 휴식을 즐긴다", "목적지까지 최대한 빨리 간다"]
    },
    {
      "question": "자전거 도로에서 큰 길로 이어질 때",
      "type": "like",
      "keyword": "안전",
      "options": ["빠르고 직선인 큰 길을 택한다", "안전한 자전거 전용 도로로 우회한다"]
    },
    {
      "question": "앗! 길을 가는데 사람이 너무 많다!",
      "type": "dislike",
      "keyword": "통행량",
      "options": ["할 수 없이 자전거에서 내리거나 다른 길로 돌아간다", "따르릉 따르릉 비켜나세요~ 그냥 지나간다"]
    },
    {
      "question": "평화로운 산길을 달릴 때",
      "type": "like",
      "keyword": "속도",
      "options": ["속도를 내며 도착시간을 줄인다", "경치를 즐기며 천천히 주행한다"]
    },
    {
      "question": "신호등이 많은 길을 지날 때",
      "type": "dislike",
      "keyword": "신호",
      "options": ["잠시도 멈추기 싫어 다른 길로 떠난다.", "신호가 있어도 괜찮아 그대로 간다"]
    },
    {
      "question": "주행을 하다가 오르막을 마주쳤을 때",
      "type": "dislike",
      "keyword": "오르막",
      "options": ["한숨을 쉬며 자전거에서 내려서 끌고 간다", "아무도 나를 막을 수 없다. 빠르게 올라간다"],
    }
  ];

  int currentQuestionIndex = 0;

  void _selectOption(String type, String keyword, bool isLiked) {
    final preferenceProvider =
        Provider.of<PreferenceProvider>(context, listen: false);
    if (type == "like") {
      isLiked
          ? preferenceProvider.addLike(keyword)
          : preferenceProvider.removeLike(keyword);
    } else {
      isLiked
          ? preferenceProvider.addDislike(keyword)
          : preferenceProvider.removeDislike(keyword);
    }
  }

  void _nextQuestion() {
    setState(() {
      currentQuestionIndex++;
    });

    if (currentQuestionIndex >= surveyQuestions.length) {
      _navigateToResultPage();
    }
  }

  void _navigateToResultPage() {
    final preferenceProvider =
        Provider.of<PreferenceProvider>(context, listen: false);
    final resultType = _determineResultType(
        preferenceProvider.likes, preferenceProvider.dislikes);

    ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.lightGreen,
        padding: EdgeInsets.symmetric(vertical: 15, horizontal: 50),
      ),
      onPressed: () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) {
              return SurveyResultPage(resultType: resultType);
            },
          ),
        );
      },
      child: const Text(
        '결과 보러가기',
        style: TextStyle(fontSize: 16, color: Colors.white),
      ),
    );
  }

  String _determineResultType(List<String> likes, List<String> dislikes) {
    if (likes.contains("풍경") && !likes.contains("속도")) {
      return "scenery";
    } else if (likes.contains("속도") &&
        dislikes.contains("신호") &&
        !dislikes.contains("오르막")) {
      return "health";
    } else if (likes.contains("안전") && !dislikes.contains("신호")) {
      return "safety";
    } else {
      return "fast";
    }
  }

  Map<String, int> _determineAttributes(
      List<String> likes, List<String> dislikes) {
    final results = likes + dislikes;
    final attributes = {
      "scenery": 0,
      "safety": 0,
      "traffic": 0,
      "fast": 0,
      "signal": 0,
      "uphill": 0,
      "bigRoad": 0,
      "bikePath": 0,
    };
    if (results.contains("풍경")) {
      attributes["scenery"] = 1;
    } else {
      attributes["scenery"] = -1;
    }
    if (results.contains("안전")) {
      attributes["safety"] = 1;
    } else {
      attributes["safety"] = -1;
    }
    if (results.contains("통행량")) {
      attributes["traffic"] = -1;
    } else {
      attributes["traffic"] = 1;
    }
    if (results.contains("속도")) {
      attributes["fast"] = 1;
    } else {
      attributes["fast"] = -1;
    }
    if (results.contains("신호")) {
      attributes["signal"] = -1;
    } else {
      attributes["signal"] = 1;
    }
    if (results.contains("오르막")) {
      attributes["uphill"] = -1;
    } else {
      attributes["uphill"] = 1;
    }
    return attributes;
  }

  @override
  Widget build(BuildContext context) {
    if (currentQuestionIndex >= surveyQuestions.length) {
      final preferenceProvider =
          Provider.of<PreferenceProvider>(context, listen: false);
      final resultType = _determineResultType(
          preferenceProvider.likes, preferenceProvider.dislikes);
      final attributes = _determineAttributes(
          preferenceProvider.likes, preferenceProvider.dislikes);

      return Container(
        decoration: BoxDecoration(color: Colors.white),
        child: Center(
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.lightGreen,
              padding: EdgeInsets.symmetric(vertical: 15, horizontal: 50),
            ),
            onPressed: () {
              _firestore
                  .collection('users')
                  .doc(_authentication.currentUser?.uid)
                  .update({
                'attributes': attributes,
              });
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) {
                    return SurveyResultPage(resultType: resultType);
                  },
                ),
              );
            },
            child: const Text(
              '결과 보러가기',
              style: TextStyle(fontSize: 16, color: Colors.white),
            ),
          ),
        ),
      );

      //return Center(child: CircularProgressIndicator());
    }

    final questionData = surveyQuestions[currentQuestionIndex];
    return Scaffold(
      body: Column(
        children: [
          LinearProgressIndicator(
            value: (currentQuestionIndex + 1) / surveyQuestions.length,
            minHeight: 5,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    questionData["question"],
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.lightGreen[600]),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),
                  Column(
                    children: List.generate(2, (index) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.lightGreen[200],
                            padding: const EdgeInsets.symmetric(
                                horizontal: 50, vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          onPressed: () {
                            _selectOption(
                              questionData["type"],
                              questionData["keyword"],
                              index == 0,
                            );
                            _nextQuestion();
                          },
                          child: Text(
                            questionData["options"][index],
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.black),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
