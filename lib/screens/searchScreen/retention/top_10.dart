import 'package:flutter/material.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';

final _firestore = FirebaseFirestore.instance;
final _authentication = FirebaseAuth.instance;

class Top10 extends StatefulWidget {
  const Top10({super.key});

  @override
  State<Top10> createState() => _Top10State();
}

class _Top10State extends State<Top10> {
  String fullName = 'loading...';
  num totalDistance = 0; // 주행 거리 초기값
  String ranking = '집계 중...';
  List<Map<String, dynamic>> top10Users = [];

  @override
  void initState() {
    super.initState();
    _fetchUserData();
    _fetchRankings({"uid": _authentication.currentUser?.uid});
  }

  Future<void> _fetchUserData() async {
    try {
      final userDoc = await _firestore
          .collection('users')
          .doc(_authentication.currentUser?.uid)
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

  Future<void> _fetchRankings(Map<String, dynamic> req) async {
    try {
      final results = await FirebaseFunctions.instanceFor(region: 'asia-northeast3')
          .httpsCallable('get_rankings')
          .call(req);
      print(results.data["ranking"]);

      // top_10_users 데이터를 안전하게 변환
      final rawTop10Users = results.data['top_10_users'] as List<dynamic>;
      final convertedTop10Users = rawTop10Users.map((user) {
        return Map<String, dynamic>.from(user as Map);
      }).toList();

      setState(() {
        ranking = "${results.data["ranking"]}위";
        top10Users = convertedTop10Users;
      });
      print(results.data['top_10_users']);

    } catch (e) {
      print("Error fetching rankings: $e");
    }
  }


  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: MediaQuery.of(context).size.width*0.9,
        height: MediaQuery.of(context).size.height*0.8,
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            SizedBox(height: 30,),
            Center(child: Text('TOP 10 라이더', style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.lightGreen[800]),),),
            SizedBox(height: 20,),
            Text('내 순위', style: TextStyle(color: Colors.lightGreen),),
            Container(padding: EdgeInsets.all(10),
              margin: EdgeInsets.symmetric(vertical: 10, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.lightGreen, width: 1),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  // 순위 표시
                  Text(
                    ranking,
                    style: TextStyle(
                      color: Colors.lightGreen,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  // 사용자 닉네임 및 부대 정보
                  Text(
                    fullName,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  Text(
                    '${(totalDistance / 1000).toStringAsFixed(2)} km',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),

            ),
            SizedBox(height: 20,),
            Text('TOP 10', style: TextStyle(color: Colors.lightGreen),),
            Expanded(
              child: top10Users.isNotEmpty
                  ? ListView.builder(
                itemCount: top10Users.length, // 상위 10명의 라이더
                itemBuilder: (BuildContext context, int index) {
                  final user = top10Users[index]; // 현재 순위의 사용자 정보
                  final userName = user['fullname'] ?? 'Unknown';
                  final userDistance = user['totalDistance'] ?? 0;

                  return Container(
                    padding: EdgeInsets.all(10),
                    margin: EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.lightGreen, width: 1),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        // 순위 표시
                        Text(
                          '${index + 1}위',
                          style: TextStyle(
                            color: Colors.lightGreen,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        // 사용자 닉네임 및 부대 정보
                        Text(
                          userName,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        Text(
                          '${(userDistance / 1000).toStringAsFixed(2)} km',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              )
                  : Center(
                child: CircularProgressIndicator(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
