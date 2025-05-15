import 'package:flutter/material.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'ranking_card.dart';
import 'top_10.dart';

final _firestore = FirebaseFirestore.instance;
final _authentication = FirebaseAuth.instance;

class ModalContent extends StatefulWidget {

  const ModalContent({super.key});

  @override
  State<ModalContent> createState() => _ModalContentState();
}

class _ModalContentState extends State<ModalContent> {
  String fullName = 'loading...'; // 사용자 이름 초기값
  num totalDistance = 0; // 주행 거리 초기값

  @override
  void initState() {
    super.initState();
    _fetchUserData();// Firestore에서 데이터 가져오기
  }

  Future<void> _fetchUserData() async {
    try {
      // Firestore에서 특정 사용자 문서를 가져옵니다.
      final userDoc = await _firestore
          .collection('users')
          .doc(_authentication.currentUser?.uid) // 해당 사용자 ID를 설정
          .get();

      if (userDoc.exists) {
        setState(() {
          fullName = userDoc['fullname'] ?? 'Unknown User';
          totalDistance = userDoc['totalDistance'] ?? 0;
        });
      } else {
        setState(() {
          fullName = 'User not found';
        });
      }
    } catch (e) {
      setState(() {
        fullName = 'Error loading user';
      });
      print("Error fetching user data: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.lightGreen[400],
          padding: EdgeInsets.symmetric(vertical: 10, horizontal: 30,),
        ),
        child: Text('$fullName님의 순위 보기 !', style: TextStyle(color: Colors.white),),
        onPressed: () {
          showModalBottomSheet<void>(
            context: context,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(50),
                topRight: Radius.circular(50),
              ),
            ),
            builder: (BuildContext context) {
              return Container(
                height: MediaQuery.of(context).size.height*0.35,
                color: Colors.transparent,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      SizedBox(height: 20,),
                      // Firestore 데이터를 표시
                      Text(
                        '$fullName 라이더님은 현재 \n    ${totalDistance/1000} km 주행 중~',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.lightGreen[800]
                        ),
                      ),

                      SizedBox(height: 10,),
                      IconButton(
                        onPressed: () {
                          // Dialog를 띄우는 코드
                          showDialog(
                            context: context,
                            builder: (context) {
                              return RankingCard();
                            },
                          );
                        },
                        visualDensity: VisualDensity(vertical: -4),
                        padding: EdgeInsets.all(0),
                        icon: Text('내 순위 카드 보기', style: TextStyle(fontSize: 15),),
                      ),
                      IconButton(
                        onPressed: () {
                          // Dialog를 띄우는 코드
                          showDialog(
                            context: context,
                            builder: (context) {
                              return Top10();
                            },
                          );
                        },
                        visualDensity: VisualDensity(vertical: -4),
                        padding: EdgeInsets.all(0),
                        icon: Text('TOP 10 라이더 보기', style: TextStyle(fontSize: 13),),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.lightGreen[400],
                          padding: EdgeInsets.symmetric(vertical: 15, horizontal: 50),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          '지금 달리러 가기 !',
                          style: TextStyle(fontSize: 16, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
