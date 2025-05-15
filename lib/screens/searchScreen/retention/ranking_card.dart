import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'dart:io';
import 'package:provider/provider.dart';


import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
// import 'package:image_gallery_saver/image_gallery_saver.dart';

import '../../../utils/providers/kakao_login_provider.dart';
import '../../profileScreen/preference_survey/kakao_share.dart';


final _firestore = FirebaseFirestore.instance;
final _authentication = FirebaseAuth.instance;

class RankingCard extends StatefulWidget {
  const RankingCard({super.key});

  @override
  State<RankingCard> createState() => _RankingCardState();
}

class _RankingCardState extends State<RankingCard> {
  String fullName = 'loading...';
  num totalDistance = 0; // 주행 거리 초기값
  String ranking = '집계 중...';

  final ScreenshotController CardScreenshotController = ScreenshotController();

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
      setState(() {
        ranking = "${results.data["ranking"]}위";
      });
    } catch (e) {
      print("Error fetching rankings: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final kakaoLoginProvider = Provider.of<KakaoLoginProvider>(context);

    return Center(
      child: Container(
        width: MediaQuery.of(context).size.width*0.9,
        height: 270,
        padding: EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Screenshot(
              controller: CardScreenshotController,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SizedBox(height: 20,),
                    Text(
                      'Ranking Card',
                      style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold, color: Colors.lightGreen),
                    ),
                    SizedBox(height: 15,),
                    Row(
                      children: [
                        if (kakaoLoginProvider.user?.kakaoAccount?.profile?.profileImageUrl != null)
                          SizedBox(
                            width: 75,
                            height: 75,
                            child: Image.network(
                              kakaoLoginProvider.user?.kakaoAccount?.profile?.profileImageUrl ?? '',
                              fit: BoxFit.contain,
                            ),
                          ),
                        SizedBox(width: 15,),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('이름: $fullName', style: TextStyle(fontSize: 16),),
                            SizedBox(height: 5,),
                            Text('주행 거리: ${totalDistance / 1000} km', style: TextStyle(fontSize: 16)),
                            SizedBox(height: 5,),
                            Text('순위: $ranking',style: TextStyle(fontSize: 16)),

                          ],
                        ),
                      ],
                    ),
                    SizedBox(height: 15,)
                  ],
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: Icon(Icons.download, color: Colors.green),
                  onPressed: () async {
                    await CardScreenshotController
                        .capture(
                        delay: Duration(milliseconds: 10),
                        pixelRatio: MediaQuery.of(context).devicePixelRatio)
                        .then((Uint8List? image) async {
                      if (image != null) {
                        final directory =
                        await getApplicationDocumentsDirectory();
                        final imagePath =
                        await File('${directory.path}/image.png').create();
                        await imagePath.writeAsBytes(image);
                        // await ImageGallerySaver.saveFile(imagePath.path,
                        //     name: 'screenshot');
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Image saved to $imagePath')), // snack bar 안보이긴 함
                        );
                      }
                    });
                  },
                  tooltip: '다운로드',
                ),
                SizedBox(width: 50),
                IconButton(
                  icon: Icon(Icons.share, color: Colors.green),
                  onPressed: () async {
                    try {
                      Uint8List? capturedImage =
                      await CardScreenshotController.capture();
                      if (capturedImage != null) {
                        await kakaoShareForRanking(capturedImage);
                      } else {
                        throw '이미지를 캡처하지 못했습니다.';
                      }
                    } catch (error) {
                      print('공유 실패: $error');
                    }
                  },
                  tooltip: '공유',
                ),
              ],
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('닫기', style: TextStyle(color: Colors.black38, fontSize: 15),),
            ),
          ],
        ),
      ),
    );
  }
}
